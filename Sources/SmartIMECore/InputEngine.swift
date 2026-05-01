import Foundation

/// 主輸入引擎 - 整合所有組件
public class InputEngine {
    
    // 組態
    private let config: InputEngineConfig
    private var resourcesLoaded: Bool = false
    private let workQueue = DispatchQueue(label: "InputEngine.Work", qos: .userInitiated)
    private var requestSerial: Int = 0
    private let stateLock = NSLock()
    
    // 核心組件
    private let languageDetector: LanguageDetector
    private let fusionDetector: LanguageDetectionFusion
    private let bopomofoConverter: BopomofoConverter
    private let keyboardMapper: KeyboardMapper
    private let ngramModel: NgramModel
    private let chineseTrie: WordLookup
    private let englishTrie: WordLookup
    private let userDictionary: UserDictionary
    
    // 輸入狀態（執行緒安全）
    private let inputBufferSnapshot = ThreadSafeSnapshot("")
    private let contextWordsSnapshot = ThreadSafeSnapshot([String]())
    private let candidatesSnapshot = ThreadSafeSnapshot([Candidate]())
    private let maxContextSize = 3
    
    /// 候選詞結構
    public struct Candidate {
        public let text: String
        public let score: Double
        public let source: CandidateSource
        
        public enum CandidateSource {
            case bopomofoConversion
            case englishCompletion
            case contextPrediction
        }
    }
    
    public init() {
        self.config = .default
        self.languageDetector = LanguageDetector()
        self.ngramModel = NgramModel()
        self.chineseTrie = RadixTrie()
        self.englishTrie = RadixTrie()
        self.bopomofoConverter = BopomofoConverter(ngramModel: ngramModel, trie: chineseTrie)
        self.keyboardMapper = KeyboardMapper()
        self.userDictionary = UserDictionary()
        self.fusionDetector = LanguageDetectionFusion(ruleDetector: languageDetector, classifier: LanguageClassifier())
        if !config.lazyLoadResources {
            loadResources()
            resourcesLoaded = true
        }
    }

    /// 以設定初始化（向後相容：不破壞既有 init()）
    init(config: InputEngineConfig) {
        self.config = config
        self.languageDetector = LanguageDetector()
        self.ngramModel = NgramModel()
        self.chineseTrie = RadixTrie()
        self.englishTrie = RadixTrie()
        self.bopomofoConverter = BopomofoConverter(ngramModel: ngramModel, trie: chineseTrie)
        self.keyboardMapper = KeyboardMapper()
        self.userDictionary = UserDictionary()
        self.fusionDetector = LanguageDetectionFusion(ruleDetector: languageDetector, classifier: LanguageClassifier())
        if !config.lazyLoadResources {
            loadResources()
            resourcesLoaded = true
        }
    }
    
    // MARK: - Public API
    
    /// 處理使用者輸入
    /// - Parameter input: 使用者輸入的字符
    /// - Returns: 更新後的候選詞列表
    public func handleInput(_ input: String) -> [Candidate] {
        let t = LatencyTimer()
        let newBuffer = inputBufferSnapshot.write { buffer in
            buffer += input
            return buffer
        }
        let newCandidates = updateCandidates(inputBuffer: newBuffer)
        let latency = t.endMillis()
        PerformanceDashboard.shared.recordLatency(latency)
        Telemetry.shared.logEvent("handleInput", fields: [
            "latency_ms": String(format: "%.3f", latency),
            "input_len": newBuffer.count,
            "candidates": newCandidates.count
        ])
        return newCandidates
    }
    
    /// 刪除最後一個字符
    /// - Returns: 更新後的候選詞列表
    public func deleteLastCharacter() -> [Candidate] {
        let t = LatencyTimer()
        let newBuffer = inputBufferSnapshot.write { buffer in
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return buffer
        }
        let newCandidates = updateCandidates(inputBuffer: newBuffer)
        let latency = t.endMillis()
        Telemetry.shared.logEvent("deleteLastCharacter", fields: [
            "latency_ms": String(format: "%.3f", latency),
            "input_len": newBuffer.count,
            "candidates": newCandidates.count
        ])
        return newCandidates
    }

    /// 非阻塞處理輸入（維持同步 API，不破壞原有行為）
    /// - Parameters:
    ///   - input: 使用者輸入的字符
    ///   - completion: 異步回傳候選
    func handleInputAsync(_ input: String, completion: @escaping ([Candidate]) -> Void) {
        let newBuffer = inputBufferSnapshot.write { buffer in
            buffer += input
            return buffer
        }
        let ticket = nextRequestSerial()
        let snapshotContext = contextWordsSnapshot.read { $0 }
        workQueue.async { [weak self] in
            guard let self = self else { return }
            let result = self.computeCandidates(inputBuffer: newBuffer, context: snapshotContext)
            self.publish(ticket: ticket, candidates: result, completion: completion)
        }
    }

    /// 非阻塞刪除最後一個字符
    func deleteLastCharacterAsync(completion: @escaping ([Candidate]) -> Void) {
        let newBuffer = inputBufferSnapshot.write { buffer in
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return buffer
        }
        let ticket = nextRequestSerial()
        let snapshotContext = contextWordsSnapshot.read { $0 }
        workQueue.async { [weak self] in
            guard let self = self else { return }
            let result = self.computeCandidates(inputBuffer: newBuffer, context: snapshotContext)
            self.publish(ticket: ticket, candidates: result, completion: completion)
        }
    }
    
    /// 選擇候選詞
    /// - Parameter index: 候選詞索引
    public func selectCandidate(at index: Int) {
        let currentCandidates = candidatesSnapshot.read { $0 }
        guard index < currentCandidates.count else { return }
        
        let selected = currentCandidates[index]
        
        // 更新上下文
        contextWordsSnapshot.write { context in
            context.append(selected.text)
            if context.count > maxContextSize {
                context.removeFirst()
            }
            return context
        }
        
        // 清空輸入緩衝和候選詞
        inputBufferSnapshot.write { $0 = "" }
        candidatesSnapshot.write { $0 = [] }
        
        // 學習用戶選字
        userDictionary.learn(selected.text, delta: 1)
        // 持久化用戶詞庫（若提供路徑）
        if let path = config.resourcePaths?["user_dict"] {
            try? userDictionary.save(to: path)
        }
    }
    
    /// 獲取當前輸入緩衝內容
    public var currentInput: String {
        return inputBufferSnapshot.read { $0 }
    }
    
    /// 獲取當前組字字串 (已轉換為注音符號，用於 UI 顯示)
    public var compositionString: String {
        let raw = currentInput
        return keyboardMapper.convert(raw)
    }
    
    /// 獲取當前上下文
    public var currentContext: [String] {
        return contextWordsSnapshot.read { $0 }
    }
    
    /// 獲取當前候選詞
    public func getCandidates() -> [Candidate] {
        return candidatesSnapshot.read { $0 }
    }
    
    /// 清空輸入
    public func clearInput() {
        inputBufferSnapshot.write { $0 = "" }
        candidatesSnapshot.write { $0 = [] }
    }
    
    /// 重置引擎（包括上下文）
    public func reset() {
        inputBufferSnapshot.write { $0 = "" }
        candidatesSnapshot.write { $0 = [] }
        contextWordsSnapshot.write { $0 = [] }
        languageDetector.clearHistory()
    }
    
    // MARK: - Private Methods
    
    /// 更新候選詞列表（不可變版本）
    private func updateCandidates(inputBuffer: String) -> [Candidate] {
        guard !inputBuffer.isEmpty else { return [] }
        
        if !resourcesLoaded {
            loadResources()
            resourcesLoaded = true
        }
        
        // 1. 檢測語言
        let context = contextWordsSnapshot.snapshot()
        let detectionFused = fusionDetector.detect(inputBuffer, context: context)
        
        // 2. 始終生成中英文候選，用檢測結果決定權重
        var tempCandidates: [Candidate] = []
        tempCandidates.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
        tempCandidates.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
        
        // 3. 動態權重：根據語言檢測信心度調整 source weights
        let chineseWeight: Double
        let englishWeight: Double
        switch detectionFused.language {
        case .chinese:
            chineseWeight = 1.2 + detectionFused.confidence * 0.5
            englishWeight = max(0.3, 1.0 - detectionFused.confidence * 0.5)
        case .english:
            chineseWeight = max(0.3, 1.0 - detectionFused.confidence * 0.5)
            englishWeight = 1.2 + detectionFused.confidence * 0.5
        case .mixed, .unknown:
            chineseWeight = 1.0
            englishWeight = 1.0
        }
        
        // 4. 融合、排序與截斷
        let boosted = tempCandidates.map { c in
            CandidateFusion.Item(text: c.text, score: userDictionary.boostScore(for: c.text, base: c.score), source: c.source)
        }
        let fused = CandidateFusion.fuse(
            boosted,
            sourceWeights: [.bopomofoConversion: chineseWeight, .englishCompletion: englishWeight, .contextPrediction: 0.9],
            limit: config.maxCandidates
        )
        let finalCandidates = fused.map { Candidate(text: $0.text, score: $0.score, source: $0.source) }
        
        // 5. 更新快照
        candidatesSnapshot.write { $0 = finalCandidates }
        
        return finalCandidates
    }

    /// 計算候選（供 async 路徑使用，不改變共享狀態）
    private func computeCandidates(inputBuffer: String, context: [String]) -> [Candidate] {
        if inputBuffer.isEmpty {
            return []
        }
        if !resourcesLoaded {
            loadResources()
            resourcesLoaded = true
        }
        var temp: [Candidate] = []
        let detectionFused = fusionDetector.detect(inputBuffer, context: context)
        
        // 始終生成中英文候選
        temp.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
        temp.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
        
        // 動態權重
        let chineseWeight: Double
        let englishWeight: Double
        switch detectionFused.language {
        case .chinese:
            chineseWeight = 1.2 + detectionFused.confidence * 0.5
            englishWeight = max(0.3, 1.0 - detectionFused.confidence * 0.5)
        case .english:
            chineseWeight = max(0.3, 1.0 - detectionFused.confidence * 0.5)
            englishWeight = 1.2 + detectionFused.confidence * 0.5
        case .mixed, .unknown:
            chineseWeight = 1.0
            englishWeight = 1.0
        }
        
        let boosted = temp.map { c in
            CandidateFusion.Item(text: c.text, score: userDictionary.boostScore(for: c.text, base: c.score), source: c.source)
        }
        let fused = CandidateFusion.fuse(
            boosted,
            sourceWeights: [.bopomofoConversion: chineseWeight, .englishCompletion: englishWeight, .contextPrediction: 0.9],
            limit: config.maxCandidates
        )
        return fused.map { Candidate(text: $0.text, score: $0.score, source: $0.source) }
    }

    private func publish(ticket: Int, candidates: [Candidate], completion: @escaping ([Candidate]) -> Void) {
        // 僅發布最新請求結果，避免過時結果覆蓋
        if ticket == requestSerial {
            candidatesSnapshot.write { $0 = candidates }
            completion(candidates)
        }
    }

    private func nextRequestSerial() -> Int {
        requestSerial += 1
        return requestSerial
    }
    

    private func generateChineseCandidatesSnapshot(inputBuffer: String, context: [String]) -> [Candidate] {
        var list: [Candidate] = []
        
        // 判斷輸入類型並決定 Bopomofo 源
        var bopomofoInput = inputBuffer
        let isDirectBopomofo = inputBuffer.unicodeScalars.contains { $0.value >= 0x3100 && $0.value <= 0x312F }
        
        if !isDirectBopomofo && inputBuffer.allSatisfy({ $0.isASCII }) {
            // ASCII 輸入 → 透過 KeyboardMapper 轉注音
            let mapped = keyboardMapper.convert(inputBuffer)
            // 只有當映射結果包含注音符號時才使用
            if mapped.unicodeScalars.contains(where: { $0.value >= 0x3100 && $0.value <= 0x312F }) {
                bopomofoInput = mapped
            }
        }
        
        // Bopomofo → 中文轉換
        let conversions: [(word: String, score: Double)] = context.isEmpty
            ? bopomofoConverter.convert(bopomofoInput)
            : bopomofoConverter.convertWithContext(bopomofoInput, context: context)
        for (word, score) in conversions {
            list.append(Candidate(text: word, score: score, source: .bopomofoConversion))
        }
        
        // 中文 Trie 前綴匹配
        let trieMatches = chineseTrie.getAllWordsWithPrefix(inputBuffer, limit: 5)
        for (word, frequency) in trieMatches {
            let score = Double(frequency) / 1000.0
            list.append(Candidate(text: word, score: score, source: .contextPrediction))
        }
        return list
    }
    

    private func generateEnglishCandidatesSnapshot(inputBuffer: String) -> [Candidate] {
        // 只對看起來像 ASCII 的輸入做英文匹配
        guard inputBuffer.allSatisfy({ $0.isASCII }) else { return [] }
        
        var list: [Candidate] = []
        let lower = inputBuffer.lowercased()
        let matches = englishTrie.getAllWordsWithPrefix(lower, limit: 5)
        for (word, frequency) in matches {
            let score = Double(frequency) / 1000.0
            list.append(Candidate(text: word, score: score, source: .englishCompletion))
        }
        // 若 Trie 中存在完整匹配，額外加高分候選
        if englishTrie.search(lower) {
            list.append(Candidate(text: inputBuffer, score: 0.9, source: .englishCompletion))
        }
        return list
    }
    
    /// 加載資源檔案（支援外部路徑與內建預設）
    private func loadResources() {
        var paths = config.resourcePaths ?? [:]
        var loadedCount = 0
        var errors: [String] = []
        
        // 支援 resource_manifest：若存在則解析並可能回滾
        if let manifestPath = paths["resource_manifest"], ResourceManager.fileExists(manifestPath) {
            do {
                let resolved = try VersionedResourceLoader.resolvePathsWithRollback(manifestPath: manifestPath)
                paths.merge(resolved.paths) { _, new in new }
                Telemetry.shared.logEvent("resource_manifest", fields: [
                    "version": resolved.manifest.version,
                    "rolled_back": resolved.rolledBack
                ])
            } catch {
                errors.append("manifest_failed: \(error.localizedDescription)")
            }
        }
        
        // 1) 中文詞典
        if let zhPath = paths["chinese_dictionary"], ResourceManager.fileExists(zhPath) {
            do {
                let words = try ResourceManager.loadWordFrequencies(at: zhPath)
                chineseTrie.insertBatch(words)
                loadedCount += 1
            } catch {
                errors.append("chinese_dict: \(error.localizedDescription)")
                loadChineseDictionary() // 降級到內建
            }
        } else {
            loadChineseDictionary()
        }
        
        // 2) 英文詞典
        if let enPath = paths["english_dictionary"], ResourceManager.fileExists(enPath) {
            do {
                let words = try ResourceManager.loadWordFrequencies(at: enPath)
                englishTrie.insertBatch(words)
                loadedCount += 1
            } catch {
                errors.append("english_dict: \(error.localizedDescription)")
                loadEnglishDictionary() // 降級到內建
            }
        } else {
            loadEnglishDictionary()
        }
        
        // 3) 注音詞典
        if let bpmfPath = paths["bopomofo_dictionary"], ResourceManager.fileExists(bpmfPath) {
            do {
                let pairs = try ResourceManager.loadBopomofoDictionary(at: bpmfPath)
                bopomofoConverter.loadMappings(pairs)
                loadedCount += 1
            } catch {
                errors.append("bpmf_dict: \(error.localizedDescription)")
            }
        }
        
        // 4) N-gram 模型
        if let lmPath = paths["ngram_model"], ResourceManager.fileExists(lmPath) {
            do {
                try ngramModel.load(from: lmPath)
                loadedCount += 1
            } catch {
                errors.append("ngram_model: \(error.localizedDescription)")
                trainNgramModel() // 降級到內建
            }
        } else {
            trainNgramModel()
        }
        
        // 5) 用戶詞庫
        if let userPath = paths["user_dict"], ResourceManager.fileExists(userPath) {
            do {
                try userDictionary.load(from: userPath)
                loadedCount += 1
            } catch {
                errors.append("user_dict: \(error.localizedDescription)")
            }
        }
        
        // 記錄載入結果
        Telemetry.shared.logEvent("resource_loading", fields: [
            "loaded_count": loadedCount,
            "errors": errors.joined(separator: ";")
        ])
    }

    /// 手動保存用戶詞庫（若無路徑將無動作）
    func saveUserDictionary() {
        if let path = config.resourcePaths?["user_dict"] {
            try? userDictionary.save(to: path)
        }
    }
    
    /// 加載中文詞典
    private func loadChineseDictionary() {
        let chineseWords: [(String, Int)] = [
            // --- 超高頻（>5000）---
            ("的", 9999), ("了", 9800), ("是", 9700), ("我", 9600), ("不", 9500),
            ("在", 9400), ("人", 9300), ("有", 9200), ("他", 9100), ("這", 9000),
            ("中", 8900), ("大", 8800), ("來", 8700), ("上", 8600), ("個", 8500),
            ("國", 8400), ("到", 8300), ("說", 8200), ("們", 8150), ("為", 8100),
            ("子", 8050), ("和", 8000), ("你", 7950), ("地", 7900), ("出", 7850),
            ("會", 7800), ("時", 7750), ("要", 7700), ("也", 7650), ("就", 7600),
            ("她", 7550), ("對", 7500), ("以", 7450), ("可", 7400), ("這", 7350),
            ("年", 7300), ("生", 7250), ("能", 7200), ("自", 7150), ("學", 7100),
            ("下", 7050), ("過", 7000), ("天", 6900), ("後", 6850), ("多", 6800),
            ("都", 6750), ("然", 6700), ("沒", 6650), ("日", 6600), ("於", 6550),
            ("起", 6500), ("還", 6450), ("發", 6400), ("成", 6350), ("事", 6300),
            ("只", 6250), ("作", 6200), ("當", 6150), ("想", 6100), ("看", 6050),
            ("文", 6000), ("無", 5950), ("開", 5900), ("手", 5850), ("十", 5800),
            ("用", 5750), ("著", 5700), ("行", 5650), ("方", 5600), ("如", 5550),
            ("前", 5500), ("所", 5450), ("本", 5400), ("見", 5350), ("經", 5300),
            ("頭", 5250), ("面", 5200), ("公", 5150), ("同", 5100), ("老", 5050),
            ("小", 5000),

            // --- 高頻（3000–5000）常用詞組 ---
            ("你好", 4900), ("世界", 4800), ("我們", 4750), ("他們", 4700), ("她們", 4650),
            ("什麼", 4600), ("沒有", 4550), ("知道", 4500), ("怎麼", 4450), ("可以", 4400),
            ("一個", 4350), ("現在", 4300), ("時候", 4250), ("已經", 4200), ("因為", 4150),
            ("所以", 4100), ("如果", 4050), ("但是", 4000), ("雖然", 3950), ("或者", 3900),
            ("不是", 3850), ("這個", 3800), ("那個", 3750), ("他的", 3700), ("自己", 3650),
            ("沒有", 3600), ("覺得", 3550), ("應該", 3500), ("非常", 3450), ("真的", 3400),
            ("其實", 3350), ("可能", 3300), ("需要", 3250), ("必須", 3200), ("希望", 3150),
            ("問題", 3100), ("一些", 3050), ("很多", 3000),

            // --- 中高頻（2000–3000）---
            ("今天", 2950), ("明天", 2900), ("昨天", 2850), ("每天", 2800),
            ("天氣", 2750), ("謝謝", 2700), ("再見", 2650), ("早安", 2600),
            ("晚安", 2550), ("學習", 2500), ("工作", 2450), ("生活", 2400),
            ("朋友", 2350), ("家人", 2300), ("同學", 2250), ("老師", 2200),
            ("學生", 2150), ("學校", 2100), ("公司", 2050), ("電腦", 2000),

            // --- 日常用語 ---
            ("吃飯", 1950), ("睡覺", 1900), ("喝水", 1850), ("走路", 1800),
            ("開車", 1750), ("上班", 1700), ("下班", 1650), ("回家", 1600),
            ("出門", 1550), ("看書", 1500), ("寫字", 1450), ("打字", 1400),
            ("說話", 1350), ("聊天", 1300), ("唱歌", 1250), ("跳舞", 1200),
            ("運動", 1150), ("游泳", 1100), ("跑步", 1050), ("看電影", 1000),
            ("聽音樂", 980), ("玩遊戲", 960), ("上網", 940), ("看電視", 920),

            // --- 形容詞 ---
            ("好", 1900), ("壞", 1200), ("大", 1800), ("小", 1750),
            ("多", 1700), ("少", 1650), ("高", 1600), ("低", 1550),
            ("長", 1500), ("短", 1450), ("快", 1400), ("慢", 1350),
            ("新", 1300), ("舊", 1250), ("冷", 1200), ("熱", 1150),
            ("很好", 1800), ("很多", 1750), ("很高", 1400), ("很大", 1350),
            ("很快", 1300), ("真好", 1250), ("好看", 1200), ("好吃", 1180),
            ("漂亮", 1160), ("可愛", 1140), ("厲害", 1120), ("開心", 1100),
            ("快樂", 1080), ("高興", 1060), ("難過", 1040), ("傷心", 1020),
            ("生氣", 1000), ("害怕", 980), ("緊張", 960), ("興奮", 940),
            ("感動", 920), ("辛苦", 900), ("努力", 880), ("認真", 860),
            ("聰明", 840), ("笨", 820), ("重要", 800), ("有趣", 790),
            ("無聊", 780), ("困難", 770), ("容易", 760), ("簡單", 750),
            ("複雜", 740), ("方便", 730), ("安全", 720), ("危險", 710),

            // --- 動詞 ---
            ("做", 1850), ("去", 1800), ("來", 1750), ("吃", 1700),
            ("喝", 1650), ("看", 1600), ("聽", 1550), ("說", 1500),
            ("寫", 1450), ("讀", 1400), ("學", 1350), ("教", 1300),
            ("買", 1250), ("賣", 1200), ("給", 1150), ("送", 1100),
            ("拿", 1050), ("放", 1000), ("找", 980), ("幫", 960),
            ("問", 940), ("回答", 920), ("告訴", 900), ("相信", 880),
            ("了解", 860), ("明白", 840), ("記得", 820), ("忘記", 800),
            ("喜歡", 780), ("討厭", 760), ("愛", 750), ("恨", 730),
            ("等", 720), ("走", 710), ("跑", 700), ("飛", 690),
            ("開始", 680), ("結束", 670), ("完成", 660), ("準備", 650),
            ("決定", 640), ("選擇", 630), ("改變", 620), ("繼續", 610),
            ("停止", 600), ("離開", 590), ("回來", 580), ("出去", 570),
            ("進來", 560), ("上去", 550), ("下來", 540), ("過來", 530),

            // --- 名詞：人物 ---
            ("爸爸", 1100), ("媽媽", 1080), ("哥哥", 900), ("姊姊", 890),
            ("弟弟", 880), ("妹妹", 870), ("爺爺", 800), ("奶奶", 790),
            ("先生", 850), ("太太", 840), ("小姐", 830), ("孩子", 820),
            ("寶寶", 810), ("男人", 800), ("女人", 790), ("醫生", 780),
            ("護士", 770), ("警察", 760), ("軍人", 750), ("老闆", 740),

            // --- 名詞：地方 ---
            ("家", 1100), ("學校", 1050), ("公司", 1000), ("醫院", 900),
            ("餐廳", 890), ("商店", 880), ("超市", 870), ("銀行", 860),
            ("圖書館", 850), ("公園", 840), ("車站", 830), ("機場", 820),
            ("飯店", 810), ("教室", 800), ("辦公室", 790), ("廁所", 780),
            ("廚房", 770), ("客廳", 760), ("臥室", 750), ("陽台", 740),

            // --- 名詞：物品 ---
            ("手機", 1100), ("電腦", 1050), ("書", 1000), ("筆", 950),
            ("紙", 940), ("桌子", 930), ("椅子", 920), ("門", 910),
            ("窗戶", 900), ("車", 890), ("衣服", 880), ("鞋子", 870),
            ("包包", 860), ("錢", 850), ("水", 840), ("飯", 830),
            ("菜", 820), ("肉", 810), ("魚", 800), ("茶", 790),
            ("咖啡", 780), ("牛奶", 770), ("麵包", 760), ("蛋糕", 750),
            ("蘋果", 740), ("香蕉", 730), ("葡萄", 720), ("西瓜", 710),

            // --- 名詞：時間 ---
            ("時間", 1200), ("早上", 1100), ("中午", 1050), ("下午", 1000),
            ("晚上", 980), ("白天", 960), ("夜晚", 940), ("星期", 920),
            ("月", 900), ("年", 880), ("小時", 860), ("分鐘", 840),
            ("秒", 820), ("上午", 800), ("半夜", 780), ("週末", 760),
            ("假日", 750), ("平日", 740), ("過去", 730), ("未來", 720),
            ("現在", 710), ("剛才", 700), ("等一下", 690), ("馬上", 680),
            ("星期一", 670), ("星期二", 660), ("星期三", 650), ("星期四", 640),
            ("星期五", 630), ("星期六", 620), ("星期日", 610),

            // --- 名詞：自然 ---
            ("太陽", 800), ("月亮", 790), ("星星", 780), ("天空", 770),
            ("雲", 760), ("雨", 750), ("雪", 740), ("風", 730),
            ("山", 720), ("河", 710), ("海", 700), ("湖", 690),
            ("樹", 680), ("花", 670), ("草", 660), ("動物", 650),
            ("狗", 640), ("貓", 630), ("鳥", 620), ("魚", 610),

            // --- 數字量詞 ---
            ("一", 2500), ("二", 2400), ("三", 2300), ("四", 2200),
            ("五", 2100), ("六", 2000), ("七", 1900), ("八", 1800),
            ("九", 1700), ("十", 1600), ("百", 1500), ("千", 1400),
            ("萬", 1300), ("個", 2000), ("隻", 900), ("本", 880),
            ("件", 870), ("位", 860), ("次", 850), ("張", 840),
            ("把", 830), ("塊", 820), ("杯", 810), ("瓶", 800),
            ("雙", 790), ("條", 780), ("台", 770), ("份", 760),

            // --- 介詞連詞 ---
            ("和", 2500), ("跟", 2400), ("在", 2300), ("從", 2200),
            ("到", 2100), ("對", 2000), ("向", 1900), ("把", 1800),
            ("被", 1700), ("比", 1600), ("讓", 1500), ("給", 1400),
            ("而", 1300), ("但", 1250), ("且", 1200), ("或", 1150),
            ("也", 1100), ("卻", 1050), ("才", 1000), ("就", 950),
            ("還", 900), ("又", 880), ("再", 860), ("都", 840),

            // --- 代詞 ---
            ("我的", 2000), ("你的", 1950), ("他的", 1900), ("她的", 1850),
            ("我們的", 1800), ("他們的", 1750), ("這裡", 1700), ("那裡", 1650),
            ("哪裡", 1600), ("這些", 1550), ("那些", 1500), ("誰", 1450),
            ("什麼", 1400), ("怎麼", 1350), ("為什麼", 1300), ("多少", 1250),

            // --- 科技相關 ---
            ("電話", 900), ("網路", 890), ("軟體", 880), ("硬體", 870),
            ("程式", 860), ("系統", 850), ("資料", 840), ("資訊", 830),
            ("檔案", 820), ("密碼", 810), ("帳號", 800), ("社群", 790),
            ("科技", 780), ("人工智慧", 770), ("機器學習", 760), ("大數據", 750),
            ("雲端", 740), ("物聯網", 730), ("區塊鏈", 720), ("虛擬", 710),
            ("數位", 700), ("智慧型", 690), ("應用程式", 680), ("遊戲", 670),
            ("影片", 660), ("照片", 650), ("音樂", 640), ("電子郵件", 630),

            // --- 教育相關 ---
            ("考試", 850), ("作業", 840), ("功課", 830), ("上課", 820),
            ("下課", 810), ("畢業", 800), ("大學", 790), ("高中", 780),
            ("國中", 770), ("國小", 760), ("研究", 750), ("論文", 740),
            ("報告", 730), ("成績", 720), ("分數", 710), ("數學", 700),
            ("英文", 690), ("中文", 680), ("科學", 670), ("歷史", 660),

            // --- 飲食相關 ---
            ("早餐", 850), ("午餐", 840), ("晚餐", 830), ("點心", 820),
            ("水果", 810), ("蔬菜", 800), ("便當", 790), ("炒飯", 780),
            ("麵條", 770), ("火鍋", 760), ("烤肉", 750), ("甜點", 740),
            ("飲料", 730), ("果汁", 720), ("可樂", 710), ("啤酒", 700),
            ("紅茶", 690), ("綠茶", 680), ("奶茶", 670), ("豆漿", 660),
            ("泡麵", 650), ("雞排", 640), ("牛排", 630), ("蛋糕", 620),

            // --- 交通相關 ---
            ("公車", 850), ("捷運", 840), ("火車", 830), ("高鐵", 820),
            ("飛機", 810), ("腳踏車", 800), ("計程車", 790), ("摩托車", 780),
            ("汽車", 770), ("船", 760), ("紅綠燈", 750), ("斑馬線", 740),
            ("馬路", 730), ("十字路口", 720), ("高速公路", 710), ("停車場", 700),

            // --- 身體相關 ---
            ("身體", 850), ("頭", 840), ("眼睛", 830), ("耳朵", 820),
            ("鼻子", 810), ("嘴巴", 800), ("牙齒", 790), ("手", 780),
            ("腳", 770), ("心", 760), ("肚子", 750), ("背", 740),
            ("頭髮", 730), ("皮膚", 720), ("血", 710), ("骨頭", 700),

            // --- 情感心理 ---
            ("愛情", 850), ("友情", 840), ("親情", 830), ("幸福", 820),
            ("夢想", 810), ("回憶", 800), ("思念", 790), ("感覺", 780),
            ("心情", 770), ("態度", 760), ("價值", 750), ("意義", 740),
            ("目標", 730), ("計劃", 720), ("經驗", 710), ("機會", 700),
            ("勇氣", 690), ("信心", 680), ("耐心", 670), ("責任", 660),

            // --- 台灣地名 ---
            ("台灣", 900), ("台北", 890), ("台中", 880), ("台南", 870),
            ("高雄", 860), ("新竹", 850), ("桃園", 840), ("基隆", 830),
            ("花蓮", 820), ("台東", 810), ("嘉義", 800), ("彰化", 790),
            ("南投", 780), ("屏東", 770), ("宜蘭", 760), ("苗栗", 750),

            // --- 輸入法相關 ---
            ("輸入法", 900), ("注音", 890), ("注音輸入", 880), ("打字", 870),
            ("鍵盤", 860), ("候選詞", 850), ("選字", 840), ("拼音", 830),
            ("繁體", 820), ("簡體", 810), ("標點符號", 800), ("句號", 790),
            ("逗號", 780), ("問號", 770), ("驚嘆號", 760), ("括號", 750),

            // --- 常用短語 ---
            ("不好意思", 900), ("沒關係", 890), ("對不起", 880), ("請問", 870),
            ("不客氣", 860), ("太好了", 850), ("加油", 840), ("辛苦了", 830),
            ("恭喜", 820), ("生日快樂", 810), ("新年快樂", 800), ("聖誕快樂", 790),
            ("早安", 780), ("午安", 770), ("晚安", 760), ("你好嗎", 750),
            ("好久不見", 740), ("保重", 730), ("一路順風", 720), ("萬事如意", 710),

            // --- 顏色 ---
            ("紅色", 800), ("藍色", 790), ("綠色", 780), ("黃色", 770),
            ("白色", 760), ("黑色", 750), ("紫色", 740), ("橘色", 730),
            ("粉紅色", 720), ("灰色", 710), ("咖啡色", 700), ("金色", 690),

            // --- 天氣 ---
            ("晴天", 800), ("陰天", 790), ("下雨", 780), ("下雪", 770),
            ("颱風", 760), ("地震", 750), ("打雷", 740), ("閃電", 730),
            ("溫度", 720), ("氣溫", 710), ("濕度", 700), ("天氣預報", 690),

            // --- 節日 ---
            ("過年", 800), ("中秋節", 790), ("端午節", 780), ("清明節", 770),
            ("元宵節", 760), ("七夕", 750), ("國慶日", 740), ("聖誕節", 730),
            ("情人節", 720), ("母親節", 710), ("父親節", 700), ("教師節", 690),

            // --- 職業 ---
            ("工程師", 800), ("設計師", 790), ("會計師", 780), ("律師", 770),
            ("記者", 760), ("作家", 750), ("導演", 740), ("演員", 730),
            ("歌手", 720), ("畫家", 710), ("廚師", 700), ("司機", 690),
            ("農夫", 680), ("漁夫", 670), ("商人", 660), ("公務員", 650),

            // --- 運動 ---
            ("籃球", 800), ("棒球", 790), ("足球", 780), ("網球", 770),
            ("羽毛球", 760), ("桌球", 750), ("排球", 740), ("高爾夫", 730),
            ("瑜伽", 720), ("健身", 710), ("散步", 700), ("爬山", 690),
            ("騎車", 680), ("滑雪", 670), ("潛水", 660), ("衝浪", 650),

            // --- 助詞語氣詞 ---
            ("啊", 2000), ("嗎", 1950), ("呢", 1900), ("吧", 1850),
            ("嘛", 1800), ("呀", 1750), ("哦", 1700), ("喔", 1650),
            ("耶", 1600), ("哈", 1550), ("嘿", 1500), ("唉", 1450),
            ("哇", 1400), ("嗯", 1350), ("喂", 1300), ("噢", 1250),

            // --- 程式相關 ---
            ("程式碼", 800), ("變數", 790), ("函數", 780), ("迴圈", 770),
            ("陣列", 760), ("物件", 750), ("類別", 740), ("介面", 730),
            ("繼承", 720), ("編譯", 710), ("除錯", 700), ("框架", 690),
            ("資料庫", 680), ("伺服器", 670), ("客戶端", 660), ("演算法", 650),
            ("開發", 640), ("測試", 630), ("部署", 620), ("維護", 610),

            // --- 副詞 ---
            ("很", 2500), ("非常", 2400), ("真", 2300), ("太", 2200),
            ("最", 2100), ("更", 2000), ("比較", 1900), ("稍微", 1800),
            ("已經", 1700), ("正在", 1650), ("馬上", 1600), ("立刻", 1550),
            ("終於", 1500), ("常常", 1450), ("偶爾", 1400), ("總是", 1350),
            ("從來", 1300), ("永遠", 1250), ("一直", 1200), ("漸漸", 1150),
            ("突然", 1100), ("忽然", 1050), ("居然", 1000), ("竟然", 950),
            ("果然", 900), ("當然", 880), ("確實", 860), ("的確", 840),

            // --- 更多常用動詞片語 ---
            ("打電話", 800), ("發訊息", 790), ("看電視", 780), ("聽音樂", 770),
            ("上網", 760), ("玩遊戲", 750), ("打電動", 740), ("拍照", 730),
            ("下載", 720), ("安裝", 710), ("更新", 700), ("刪除", 690),
            ("複製", 680), ("貼上", 670), ("搜尋", 660), ("登入", 650),
            ("登出", 640), ("設定", 630), ("取消", 620), ("確認", 610),

            // --- 網路/通訊用語 ---
            ("按讚", 800), ("分享", 790), ("留言", 780), ("私訊", 770),
            ("追蹤", 760), ("訂閱", 750), ("轉發", 740), ("推薦", 730),
            ("直播", 720), ("貼文", 710), ("限時動態", 700), ("粉絲", 690),
            ("網紅", 680), ("影片", 670), ("頻道", 660), ("APP", 650),

            // --- 學術/工作 ---
            ("會議", 800), ("簡報", 790), ("企劃", 780), ("預算", 770),
            ("進度", 760), ("效率", 750), ("品質", 740), ("績效", 730),
            ("專案", 720), ("需求", 710), ("規格", 700), ("文件", 690),
            ("合約", 680), ("協議", 670), ("客戶", 660), ("供應商", 650),
            ("面試", 640), ("履歷", 630), ("薪水", 620), ("獎金", 610),

            // --- 感嘆/口語 ---
            ("好的", 900), ("沒問題", 890), ("了解", 880), ("收到", 870),
            ("明白", 860), ("好喔", 850), ("可以啊", 840), ("沒事", 830),
            ("隨便", 820), ("無所謂", 810), ("算了", 800), ("不要", 790),
            ("拜託", 780), ("天哪", 770), ("超棒", 760), ("太扯", 750),
            ("超級", 740), ("有夠", 730), ("好想", 720), ("好累", 710),

            // --- 更多名詞 ---
            ("手錶", 800), ("眼鏡", 790), ("雨傘", 780), ("鑰匙", 770),
            ("錢包", 760), ("背包", 750), ("行李", 740), ("護照", 730),
            ("身分證", 720), ("健保卡", 710), ("信用卡", 700), ("存摺", 690),
            ("外送", 680), ("外帶", 670), ("內用", 660), ("結帳", 650),
            ("排隊", 640), ("預約", 630), ("掛號", 620), ("看診", 610),
        ]
        
        chineseTrie.insertBatch(chineseWords)
    }
    
    /// 加載英文詞典
    private func loadEnglishDictionary() {
        let englishWords: [(String, Int)] = [
            // --- 超高頻 ---
            ("the", 9999), ("be", 9800), ("to", 9700), ("of", 9600), ("and", 9500),
            ("a", 9400), ("in", 9300), ("that", 9200), ("have", 9100), ("i", 9000),
            ("it", 8900), ("for", 8800), ("not", 8700), ("on", 8600), ("with", 8500),
            ("he", 8400), ("as", 8300), ("you", 8200), ("do", 8100), ("at", 8000),
            ("this", 7900), ("but", 7800), ("his", 7700), ("by", 7600), ("from", 7500),
            ("they", 7400), ("we", 7300), ("say", 7200), ("her", 7100), ("she", 7000),
            ("or", 6900), ("an", 6800), ("will", 6700), ("my", 6600), ("one", 6500),
            ("all", 6400), ("would", 6300), ("there", 6200), ("their", 6100), ("what", 6000),

            // --- 高頻動詞 ---
            ("get", 5900), ("make", 5800), ("go", 5700), ("know", 5600), ("take", 5500),
            ("see", 5400), ("come", 5300), ("think", 5200), ("look", 5100), ("want", 5000),
            ("give", 4900), ("use", 4800), ("find", 4700), ("tell", 4600), ("ask", 4500),
            ("work", 4400), ("seem", 4300), ("feel", 4200), ("try", 4100), ("leave", 4000),
            ("call", 3900), ("need", 3800), ("become", 3700), ("keep", 3600), ("let", 3500),
            ("begin", 3400), ("show", 3300), ("hear", 3200), ("play", 3100), ("run", 3000),
            ("move", 2950), ("live", 2900), ("believe", 2850), ("hold", 2800), ("bring", 2750),
            ("happen", 2700), ("write", 2650), ("sit", 2600), ("stand", 2550), ("lose", 2500),
            ("pay", 2450), ("meet", 2400), ("include", 2350), ("continue", 2300), ("set", 2250),
            ("learn", 2200), ("change", 2150), ("lead", 2100), ("understand", 2050), ("watch", 2000),
            ("follow", 1950), ("stop", 1900), ("create", 1850), ("speak", 1800), ("read", 1750),
            ("spend", 1700), ("grow", 1650), ("open", 1600), ("walk", 1550), ("win", 1500),
            ("teach", 1450), ("offer", 1400), ("remember", 1350), ("love", 1320), ("consider", 1300),
            ("appear", 1280), ("buy", 1260), ("wait", 1240), ("serve", 1220), ("die", 1200),
            ("send", 1180), ("build", 1160), ("stay", 1140), ("fall", 1120), ("cut", 1100),
            ("reach", 1080), ("kill", 1060), ("remain", 1040), ("suggest", 1020), ("raise", 1000),

            // --- 高頻名詞 ---
            ("time", 5500), ("person", 5400), ("year", 5300), ("way", 5200), ("day", 5100),
            ("thing", 5000), ("man", 4900), ("world", 4800), ("life", 4700), ("hand", 4600),
            ("part", 4500), ("child", 4400), ("eye", 4300), ("woman", 4200), ("place", 4100),
            ("work", 4000), ("week", 3900), ("case", 3800), ("point", 3700), ("company", 3600),
            ("number", 3500), ("group", 3400), ("problem", 3300), ("fact", 3200),
            ("home", 3100), ("water", 3000), ("room", 2950), ("mother", 2900), ("area", 2850),
            ("money", 2800), ("story", 2750), ("young", 2700), ("month", 2650), ("lot", 2600),
            ("right", 2550), ("study", 2500), ("book", 2450), ("word", 2400), ("business", 2350),
            ("issue", 2300), ("side", 2250), ("kind", 2200), ("head", 2150), ("house", 2100),
            ("service", 2050), ("friend", 2000), ("father", 1950), ("power", 1900), ("hour", 1850),
            ("game", 1800), ("line", 1750), ("end", 1700), ("city", 1650), ("community", 1600),
            ("name", 1550), ("president", 1500), ("team", 1450), ("minute", 1400), ("idea", 1350),
            ("body", 1300), ("information", 1280), ("back", 1260), ("parent", 1240), ("face", 1220),
            ("others", 1200), ("level", 1180), ("office", 1160), ("door", 1140), ("health", 1120),
            ("art", 1100), ("war", 1080), ("history", 1060), ("party", 1040), ("result", 1020),
            ("change", 1000), ("morning", 980), ("reason", 960), ("research", 940), ("girl", 920),
            ("guy", 900), ("food", 880), ("car", 860), ("law", 840), ("teacher", 820),
            ("force", 800), ("education", 790), ("music", 780), ("movie", 770), ("family", 760),

            // --- 高頻形容詞 ---
            ("good", 5000), ("new", 4900), ("first", 4800), ("last", 4700), ("long", 4600),
            ("great", 4500), ("little", 4400), ("own", 4300), ("other", 4200), ("old", 4100),
            ("right", 4000), ("big", 3900), ("high", 3800), ("different", 3700), ("small", 3600),
            ("large", 3500), ("next", 3400), ("early", 3300), ("important", 3200), ("few", 3100),
            ("public", 3000), ("bad", 2950), ("same", 2900), ("able", 2850), ("free", 2800),
            ("sure", 2750), ("true", 2700), ("clear", 2650), ("full", 2600), ("special", 2550),
            ("easy", 2500), ("hard", 2450), ("strong", 2400), ("possible", 2350), ("whole", 2300),
            ("real", 2250), ("certain", 2200), ("happy", 2150), ("simple", 2100), ("beautiful", 2050),
            ("fast", 2000), ("short", 1950), ("hot", 1900), ("cold", 1850), ("ready", 1800),
            ("nice", 1750), ("best", 1700), ("close", 1650), ("common", 1600), ("late", 1550),
            ("serious", 1500), ("difficult", 1450), ("perfect", 1400), ("final", 1350), ("natural", 1300),
            ("popular", 1280), ("dark", 1260), ("poor", 1240), ("fine", 1220), ("available", 1200),
            ("similar", 1180), ("recent", 1160), ("amazing", 1140), ("awesome", 1120), ("wonderful", 1100),
            ("terrible", 1080), ("correct", 1060), ("wrong", 1040), ("safe", 1020), ("dangerous", 1000),

            // --- 科技相關 ---
            ("computer", 900), ("software", 890), ("hardware", 880), ("internet", 870),
            ("website", 860), ("application", 850), ("database", 840), ("server", 830),
            ("client", 820), ("network", 810), ("system", 800), ("data", 790),
            ("file", 780), ("code", 770), ("program", 760), ("language", 750),
            ("developer", 740), ("engineer", 730), ("design", 720), ("user", 710),
            ("interface", 700), ("algorithm", 690), ("function", 680), ("variable", 670),
            ("class", 660), ("object", 650), ("method", 640), ("error", 630),
            ("bug", 620), ("debug", 610), ("test", 600), ("deploy", 590),
            ("framework", 580), ("library", 570), ("module", 560), ("package", 550),
            ("browser", 540), ("mobile", 530), ("cloud", 520), ("security", 510),
            ("machine", 500), ("learning", 490), ("artificial", 480), ("intelligence", 470),
            ("blockchain", 460), ("cryptocurrency", 450), ("virtual", 440), ("reality", 430),
            ("programming", 420), ("development", 410), ("technology", 400), ("digital", 390),

            // --- 程式語言/工具 ---
            ("swift", 850), ("python", 840), ("java", 830), ("javascript", 820),
            ("typescript", 810), ("react", 800), ("angular", 790), ("vue", 780),
            ("node", 770), ("docker", 760), ("kubernetes", 750), ("git", 740),
            ("github", 730), ("api", 720), ("rest", 710), ("graphql", 700),
            ("html", 690), ("css", 680), ("sql", 670), ("json", 660),
            ("xml", 650), ("linux", 640), ("macos", 630), ("ios", 620),
            ("android", 610), ("windows", 600), ("apple", 590), ("google", 580),

            // --- 日常生活 ---
            ("hello", 2500), ("goodbye", 2400), ("thanks", 2300), ("please", 2200), ("sorry", 2100),
            ("yes", 2000), ("no", 1950), ("maybe", 1900), ("today", 1850), ("tomorrow", 1800),
            ("yesterday", 1750), ("morning", 1700), ("afternoon", 1650), ("evening", 1600),
            ("night", 1550), ("breakfast", 1500), ("lunch", 1450), ("dinner", 1400),
            ("coffee", 1350), ("tea", 1300), ("beer", 1250), ("wine", 1200),
            ("restaurant", 1150), ("hotel", 1100), ("airport", 1050), ("hospital", 1000),
            ("school", 980), ("university", 960), ("church", 940), ("store", 920),
            ("market", 900), ("bank", 880), ("library", 860), ("park", 840),
            ("street", 820), ("building", 800), ("apartment", 780), ("garden", 760),
            ("kitchen", 740), ("bedroom", 720), ("bathroom", 700), ("office", 680),

            // --- 交通 ---
            ("car", 900), ("bus", 890), ("train", 880), ("plane", 870), ("bike", 860),
            ("taxi", 850), ("ship", 840), ("subway", 830), ("truck", 820), ("motorcycle", 810),

            // --- 食物 ---
            ("food", 900), ("bread", 890), ("rice", 880), ("chicken", 870), ("beef", 860),
            ("pork", 850), ("fish", 840), ("egg", 830), ("milk", 820), ("cheese", 810),
            ("cake", 800), ("ice", 790), ("cream", 780), ("sugar", 770), ("salt", 760),
            ("fruit", 750), ("apple", 740), ("banana", 730), ("orange", 720), ("grape", 710),
            ("pizza", 700), ("pasta", 690), ("salad", 680), ("soup", 670), ("sandwich", 660),
            ("chocolate", 650), ("cookie", 640), ("noodle", 630), ("sushi", 620), ("steak", 610),

            // --- 自然 ---
            ("sun", 800), ("moon", 790), ("star", 780), ("sky", 770), ("cloud", 760),
            ("rain", 750), ("snow", 740), ("wind", 730), ("mountain", 720), ("river", 710),
            ("ocean", 700), ("lake", 690), ("tree", 680), ("flower", 670), ("animal", 660),
            ("dog", 650), ("cat", 640), ("bird", 630), ("horse", 620), ("lion", 610),

            // --- 動作/運動 ---
            ("sport", 800), ("basketball", 790), ("football", 780), ("soccer", 770), ("tennis", 760),
            ("baseball", 750), ("swimming", 740), ("running", 730), ("exercise", 720), ("gym", 710),
            ("yoga", 700), ("dance", 690), ("sing", 680), ("cook", 670), ("drive", 660),
            ("travel", 650), ("sleep", 640), ("eat", 630), ("drink", 620), ("shop", 610),

            // --- 情感 ---
            ("happy", 800), ("sad", 790), ("angry", 780), ("excited", 770), ("tired", 760),
            ("nervous", 750), ("surprised", 740), ("scared", 730), ("proud", 720), ("jealous", 710),
            ("grateful", 700), ("curious", 690), ("lonely", 680), ("bored", 670), ("confused", 660),
            ("disappointed", 650), ("frustrated", 640), ("relaxed", 630), ("confident", 620), ("anxious", 610),

            // --- 顏色 ---
            ("red", 800), ("blue", 790), ("green", 780), ("yellow", 770), ("black", 760),
            ("white", 750), ("purple", 740), ("orange", 730), ("pink", 720), ("brown", 710),
            ("gray", 700), ("gold", 690), ("silver", 680),

            // --- 身體 ---
            ("head", 800), ("face", 790), ("eye", 780), ("ear", 770), ("nose", 760),
            ("mouth", 750), ("hand", 740), ("foot", 730), ("arm", 720), ("leg", 710),
            ("heart", 700), ("brain", 690), ("blood", 680), ("bone", 670), ("skin", 660),
            ("hair", 650), ("tooth", 640), ("finger", 630), ("shoulder", 620), ("knee", 610),

            // --- 衣物 ---
            ("shirt", 800), ("pants", 790), ("dress", 780), ("shoes", 770), ("hat", 760),
            ("jacket", 750), ("coat", 740), ("sweater", 730), ("jeans", 720), ("skirt", 710),
            ("socks", 700), ("gloves", 690), ("boots", 680), ("tie", 670), ("suit", 660),

            // --- 職業 ---
            ("doctor", 800), ("nurse", 790), ("lawyer", 780), ("teacher", 770), ("student", 760),
            ("artist", 750), ("writer", 740), ("singer", 730), ("actor", 720), ("director", 710),
            ("scientist", 700), ("journalist", 690), ("chef", 680), ("farmer", 670), ("pilot", 660),
            ("driver", 650), ("manager", 640), ("accountant", 630), ("dentist", 620), ("architect", 610),

            // --- 學科 ---
            ("math", 800), ("science", 790), ("english", 780), ("chinese", 770), ("physics", 760),
            ("chemistry", 750), ("biology", 740), ("economics", 730), ("philosophy", 720),
            ("psychology", 710), ("sociology", 700), ("geography", 690), ("literature", 680),

            // --- 副詞 ---
            ("very", 3000), ("also", 2900), ("just", 2800), ("now", 2700), ("then", 2600),
            ("here", 2500), ("only", 2400), ("really", 2300), ("already", 2200), ("always", 2100),
            ("never", 2000), ("often", 1950), ("sometimes", 1900), ("usually", 1850), ("still", 1800),
            ("again", 1750), ("almost", 1700), ("enough", 1650), ("quite", 1600), ("together", 1550),
            ("probably", 1500), ("actually", 1450), ("finally", 1400), ("suddenly", 1350), ("quickly", 1300),
            ("slowly", 1250), ("carefully", 1200), ("exactly", 1150), ("certainly", 1100), ("especially", 1050),
            ("definitely", 1000), ("absolutely", 980), ("basically", 960), ("obviously", 940), ("eventually", 920),

            // --- 介/連詞 ---
            ("about", 3000), ("after", 2900), ("before", 2800), ("between", 2700), ("because", 2600),
            ("however", 2500), ("although", 2400), ("while", 2300), ("since", 2200), ("until", 2100),
            ("without", 2000), ("during", 1950), ("against", 1900), ("through", 1850), ("though", 1800),
            ("whether", 1750), ("unless", 1700), ("despite", 1650), ("instead", 1600), ("besides", 1550),

            // --- 常用短語 ---
            ("thank", 1500), ("welcome", 1480), ("excuse", 1460), ("congratulations", 1440),
            ("absolutely", 1420), ("wonderful", 1400), ("amazing", 1380), ("awesome", 1360),
            ("beautiful", 1340), ("interesting", 1320), ("important", 1300), ("different", 1280),
            ("possible", 1260), ("necessary", 1240), ("available", 1220), ("successful", 1200),
            ("professional", 1180), ("international", 1160), ("traditional", 1140), ("comfortable", 1120),
            ("responsibility", 1100), ("opportunity", 1080), ("experience", 1060), ("information", 1040),
            ("environment", 1020), ("communication", 1000), ("relationship", 980), ("entertainment", 960),
        ]
        
        englishTrie.insertBatch(englishWords)
    }
    
    /// 訓練 N-gram 模型
    private func trainNgramModel() {
        let corpus: [[String]] = [
            // --- 日常問候 ---
            ["你好", "世界"], ["你好", "嗎"], ["早安", "你好"],
            ["謝謝", "你"], ["謝謝", "你的", "幫忙"],
            ["再見", "朋友"], ["再見", "明天", "見"],

            // --- 日常對話 ---
            ["我", "是", "學生"], ["我", "是", "老師"], ["我", "是", "工程師"],
            ["他", "是", "我的", "朋友"], ["她", "是", "我的", "同學"],
            ["我", "喜歡", "學習"], ["我", "喜歡", "看書"], ["我", "喜歡", "運動"],
            ["你", "想", "吃", "什麼"], ["你", "想", "去", "哪裡"],
            ["我", "不", "知道"], ["我", "不", "確定"], ["我", "不", "想", "去"],
            ["我", "覺得", "很好"], ["我", "覺得", "不錯"], ["我", "覺得", "很", "有趣"],
            ["你", "覺得", "怎麼樣"], ["你", "有", "什麼", "問題"],

            // --- 天氣相關 ---
            ["今天", "天氣", "很好"], ["今天", "天氣", "不錯"],
            ["明天", "會", "下雨"], ["明天", "天氣", "怎麼樣"],
            ["天氣", "很", "熱"], ["天氣", "很", "冷"],
            ["今天", "很", "熱"], ["今天", "很", "冷"],
            ["下雨", "了"], ["出", "太陽", "了"],

            // --- 工作學習 ---
            ["今天", "工作", "很", "忙"], ["工作", "很", "辛苦"],
            ["我", "在", "學習", "中文"], ["我", "在", "學習", "程式"],
            ["學習", "很", "重要"], ["學習", "很", "有趣"],
            ["我", "要", "上班"], ["我", "要", "下班"],
            ["明天", "要", "上班"], ["今天", "不用", "上班"],
            ["開會", "的", "時間", "到", "了"],
            ["我", "完成", "了", "報告"], ["我", "寫", "完", "了", "作業"],

            // --- 飲食相關 ---
            ["我們", "去", "吃飯", "吧"], ["我", "想", "吃", "早餐"],
            ["你", "想", "喝", "什麼"], ["我", "要", "喝", "咖啡"],
            ["這個", "很", "好吃"], ["晚餐", "吃", "什麼"],
            ["我", "想", "吃", "火鍋"], ["我們", "去", "吃", "牛排"],
            ["喝", "一杯", "茶"], ["來", "一杯", "奶茶"],

            // --- 出行交通 ---
            ["我", "要", "去", "學校"], ["我", "要", "去", "公司"],
            ["搭", "捷運", "去"], ["搭", "公車", "去"],
            ["我", "要", "回家"], ["我", "到", "家", "了"],
            ["等", "公車"], ["搭", "計程車"],
            ["開車", "去", "公司"], ["騎", "腳踏車", "去", "學校"],

            // --- 情感表達 ---
            ["我", "很", "開心"], ["我", "很", "高興"],
            ["我", "很", "難過"], ["我", "很", "傷心"],
            ["太", "好", "了"], ["太", "棒", "了"],
            ["辛苦", "了"], ["加油"],
            ["恭喜", "你"], ["生日", "快樂"],

            // --- 時間安排 ---
            ["等", "一下"], ["馬上", "就", "到"],
            ["下午", "有", "會議"], ["晚上", "有", "活動"],
            ["明天", "下午", "見"], ["星期一", "開始"],
            ["下個月", "出發"], ["今年", "畢業"],
            ["時間", "過", "得", "很", "快"],

            // --- 科技話題 ---
            ["中文", "輸入法"], ["學習", "程式", "語言"],
            ["人工智慧", "很", "厲害"], ["大數據", "分析"],
            ["手機", "很", "方便"], ["電腦", "壞", "了"],
            ["上網", "查", "資料"], ["下載", "應用程式"],
            ["程式", "有", "bug"], ["系統", "更新"],

            // --- 購物 ---
            ["我", "想", "買", "衣服"], ["這個", "多少", "錢"],
            ["太", "貴", "了"], ["可以", "便宜", "一點", "嗎"],
            ["我", "要", "買", "手機"], ["去", "超市", "買", "東西"],

            // --- 健康 ---
            ["你", "身體", "好", "嗎"], ["我", "有點", "不", "舒服"],
            ["要", "多", "運動"], ["要", "多", "喝", "水"],
            ["早點", "睡覺"], ["注意", "身體"],

            // --- 旅遊 ---
            ["我", "想", "去", "旅行"], ["我們", "去", "台北"],
            ["台灣", "很", "漂亮"], ["風景", "很", "美"],
            ["拍照", "拍", "得", "不錯"], ["旅行", "很", "開心"],

            // --- 表達意見 ---
            ["我", "同意", "你的", "看法"],
            ["你", "說", "得", "對"],
            ["我", "不", "同意"],
            ["這", "是", "一個", "好", "主意"],
            ["我", "認為", "很", "重要"],
            ["問題", "是", "什麼"],

            // --- 禮貌用語 ---
            ["不好意思", "請問"],
            ["對不起", "我", "遲到", "了"],
            ["沒關係", "不", "要緊"],
            ["請", "進"], ["請", "坐"],
            ["請問", "洗手間", "在", "哪裡"],

            // --- 描述事物 ---
            ["這個", "很", "漂亮"], ["那個", "很", "大"],
            ["他", "很", "聰明"], ["她", "很", "厲害"],
            ["這本", "書", "很", "好看"], ["那部", "電影", "很", "好看"],
            ["今天", "的", "課", "很", "有趣"],
            ["這家", "餐廳", "很", "好吃"],

            // --- 計劃安排 ---
            ["週末", "有", "什麼", "計劃"],
            ["我們", "明天", "去", "看", "電影"],
            ["下次", "一起", "吃飯"],
            ["有", "空", "的", "時候", "聊天"],
            ["計劃", "改變", "了"],

            // --- 程式開發 ---
            ["寫", "程式", "碼"], ["修", "bug"],
            ["測試", "通過", "了"], ["部署", "成功"],
            ["程式", "出", "錯", "了"], ["除錯", "中"],
            ["開發", "新", "功能"], ["更新", "版本"],

            // --- 混合句型 ---
            ["今天", "天氣", "很好", "我們", "去", "公園", "吧"],
            ["謝謝", "你", "幫", "我", "很", "大", "的", "忙"],
            ["我", "明天", "要", "去", "台北", "出差"],
            ["他", "是", "一個", "很", "好", "的", "人"],
            ["學習", "新", "事物", "讓", "我", "很", "開心"],
            ["我們", "公司", "在", "台北", "市"],
            ["你", "什麼", "時候", "有", "空"],
            ["請", "幫", "我", "看", "一下"],

            // --- 更多常用搭配 ---
            ["非常", "感謝"], ["十分", "抱歉"],
            ["沒", "問題"], ["當然", "可以"],
            ["好的", "沒", "問題"], ["不用", "客氣"],
            ["隨時", "聯繫"], ["有事", "再", "說"],
            ["平常", "都", "做", "什麼"],
            ["最近", "怎麼樣"], ["好久不見"],
            ["一切", "順利"], ["萬事", "如意"],
        ]
        
        ngramModel.train(corpus: corpus)
    }
}

// MARK: - Extensions

extension InputEngine {
    /// 獲取輸入建議（基於上下文）
    public func getSuggestions(limit: Int = 5) -> [String] {
        let context = contextWordsSnapshot.read { $0 }
        guard !context.isEmpty else { return [] }
        
        // 使用 N-gram 模型預測下一個詞
        let topWords = ngramModel.topWords(n: 20)
        let wordList = topWords.map { $0.word }
        
        let predictions = ngramModel.predictNext(context: context, candidates: wordList)
        
        return Array(predictions.prefix(limit)).map { $0.word }
    }
    
    /// 學習新詞
    func learnWord(_ word: String, language: LanguageDetector.Language) {
        switch language {
        case .chinese:
            chineseTrie.insert(word, frequency: 10)
        case .english:
            englishTrie.insert(word.lowercased(), frequency: 10)
        default:
            break
        }
    }
    
    /// 獲取統計資訊
    func getStatistics() -> [String: Any] {
        return [
            "chinese_words": chineseTrie.count,
            "english_words": englishTrie.count,
            "context_size": contextWordsSnapshot.read { $0 }.count,
            "input_buffer_length": inputBufferSnapshot.read { $0 }.count
        ]
    }
}

import Foundation

/// 主輸入引擎 - 整合所有組件
class InputEngine {
    
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
    struct Candidate {
        let text: String
        let score: Double
        let source: CandidateSource
        
        enum CandidateSource {
            case bopomofoConversion
            case englishCompletion
            case contextPrediction
        }
    }
    
    init() {
        self.config = .default
        self.languageDetector = LanguageDetector()
        self.ngramModel = NgramModel()
        self.chineseTrie = RadixTrie()
        self.englishTrie = RadixTrie()
        // 創建一個 Trie 實例用於 BopomofoConverter
        let trieForBopomofo = Trie()
        self.bopomofoConverter = BopomofoConverter(ngramModel: ngramModel, trie: trieForBopomofo)
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
        // 創建一個 Trie 實例用於 BopomofoConverter
        let trieForBopomofo = Trie()
        self.bopomofoConverter = BopomofoConverter(ngramModel: ngramModel, trie: trieForBopomofo)
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
    func handleInput(_ input: String) -> [Candidate] {
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
    func deleteLastCharacter() -> [Candidate] {
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
    func selectCandidate(at index: Int) {
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
        inputBufferSnapshot.write { _ in "" }
        candidatesSnapshot.write { _ in [] }
        
        // 學習用戶選字
        userDictionary.learn(selected.text, delta: 1)
        // 持久化用戶詞庫（若提供路徑）
        if let path = config.resourcePaths?["user_dict"] {
            try? userDictionary.save(to: path)
        }
    }
    
    /// 獲取當前輸入緩衝內容
    var currentInput: String {
        return inputBufferSnapshot.read { $0 }
    }
    
    /// 獲取當前上下文
    var currentContext: [String] {
        return contextWordsSnapshot.read { $0 }
    }
    
    /// 清空輸入
    func clearInput() {
        inputBufferSnapshot.write { _ in "" }
        candidatesSnapshot.write { _ in [] }
    }
    
    /// 重置引擎（包括上下文）
    func reset() {
        inputBufferSnapshot.write { _ in "" }
        candidatesSnapshot.write { _ in [] }
        contextWordsSnapshot.write { _ in [] }
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
        
        // 2. 根據檢測結果生成候選詞
        var tempCandidates: [Candidate] = []
        switch detectionFused.language {
        case .chinese:
            tempCandidates.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
            
        case .english:
            tempCandidates.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
            
        case .mixed:
            // 混合模式：同時生成中英文候選
            tempCandidates.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
            tempCandidates.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
            
        case .unknown:
            // 未知情況：嘗試兩種
            tempCandidates.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
            tempCandidates.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
        }
        
        // 3. 融合、排序與截斷
        let boosted = tempCandidates.map { c in
            CandidateFusion.Item(text: c.text, score: userDictionary.boostScore(for: c.text, base: c.score), source: c.source)
        }
        let fused = CandidateFusion.fuse(
            boosted,
            sourceWeights: [.bopomofoConversion: 1.2, .englishCompletion: 1.0, .contextPrediction: 0.9],
            limit: config.maxCandidates
        )
        let finalCandidates = fused.map { Candidate(text: $0.text, score: $0.score, source: $0.source) }
        
        // 4. 更新快照
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
        switch detectionFused.language {
        case .chinese:
            temp.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
        case .english:
            temp.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
        case .mixed, .unknown:
            temp.append(contentsOf: generateChineseCandidatesSnapshot(inputBuffer: inputBuffer, context: context))
            temp.append(contentsOf: generateEnglishCandidatesSnapshot(inputBuffer: inputBuffer))
        }
        let boosted = temp.map { c in
            CandidateFusion.Item(text: c.text, score: userDictionary.boostScore(for: c.text, base: c.score), source: c.source)
        }
        let fused = CandidateFusion.fuse(
            boosted,
            sourceWeights: [.bopomofoConversion: 1.2, .englishCompletion: 1.0, .contextPrediction: 0.9],
            limit: config.maxCandidates
        )
        return fused.map { Candidate(text: $0.text, score: $0.score, source: $0.source) }
    }

    private func publish(ticket: Int, candidates: [Candidate], completion: @escaping ([Candidate]) -> Void) {
        // 僅發布最新請求結果，避免過時結果覆蓋
        if ticket == requestSerial {
            candidatesSnapshot.write { _ in candidates }
            completion(candidates)
        }
    }

    private func nextRequestSerial() -> Int {
        requestSerial += 1
        return requestSerial
    }
    

    private func generateChineseCandidatesSnapshot(inputBuffer: String, context: [String]) -> [Candidate] {
        var list: [Candidate] = []
        let conversions: [(word: String, score: Double)] = context.isEmpty ? bopomofoConverter.convert(inputBuffer) : bopomofoConverter.convertWithContext(inputBuffer, context: context)
        for (word, score) in conversions {
            list.append(Candidate(text: word, score: score, source: .bopomofoConversion))
        }
        let trieMatches = chineseTrie.getAllWordsWithPrefix(inputBuffer, limit: 5)
        for (word, frequency) in trieMatches {
            let score = Double(frequency) / 1000.0
            list.append(Candidate(text: word, score: score, source: .contextPrediction))
        }
        return list
    }
    

    private func generateEnglishCandidatesSnapshot(inputBuffer: String) -> [Candidate] {
        var list: [Candidate] = []
        let matches = englishTrie.getAllWordsWithPrefix(inputBuffer.lowercased(), limit: 5)
        for (word, frequency) in matches {
            let score = Double(frequency) / 1000.0
            list.append(Candidate(text: word, score: score, source: .englishCompletion))
        }
        if englishTrie.search(inputBuffer.lowercased()) {
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
        // 這裡是一些範例詞彙
        // 實際應用中應該從完整的詞典檔案加載
        let chineseWords: [(String, Int)] = [
            ("你好", 1000),
            ("我", 800),
            ("是", 900),
            ("中文", 700),
            ("輸入法", 600),
            ("很好", 500),
            ("謝謝", 800),
            ("再見", 600),
            ("今天", 700),
            ("天氣", 650),
            ("學習", 550),
            ("工作", 600),
            ("生活", 580),
            ("朋友", 520),
            ("家人", 490),
        ]
        
        chineseTrie.insertBatch(chineseWords)
    }
    
    /// 加載英文詞典
    private func loadEnglishDictionary() {
        // 這裡是一些範例詞彙
        let englishWords: [(String, Int)] = [
            ("hello", 1000),
            ("world", 800),
            ("swift", 700),
            ("programming", 650),
            ("input", 600),
            ("method", 580),
            ("language", 750),
            ("english", 700),
            ("chinese", 680),
            ("computer", 620),
            ("keyboard", 590),
            ("typing", 560),
            ("text", 640),
            ("message", 610),
            ("application", 550),
        ]
        
        englishTrie.insertBatch(englishWords)
    }
    
    /// 訓練 N-gram 模型
    private func trainNgramModel() {
        // 使用一些範例語料訓練
        let corpus = [
            ["你好", "世界"],
            ["我", "是", "學生"],
            ["今天", "天氣", "很好"],
            ["謝謝", "你"],
            ["中文", "輸入法"],
            ["學習", "swift", "語言"],
            ["工作", "很", "忙"],
            ["朋友", "很", "好"],
        ]
        
        ngramModel.train(corpus: corpus)
    }
}

// MARK: - Extensions

extension InputEngine {
    /// 獲取輸入建議（基於上下文）
    func getSuggestions(limit: Int = 5) -> [String] {
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

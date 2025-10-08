import Cocoa
import Carbon

/// macOS 輸入法服務器
/// 負責處理系統級輸入法事件和候選詞顯示
@objc(InputMethodServer)
class InputMethodServer: NSObject {
    
    // MARK: - Properties
    
    /// 輸入法引擎（舊版）
    private let inputEngine: InputEngine
    
    /// 智能輸入引擎（新版 - 核心邏輯）
    private let smartEngine: SmartInputEngine
    
    /// 候選詞視窗
    private var candidateWindow: CandidateWindow?
    
    /// 當前輸入狀態
    private var isInputting = false
    private var currentInput = ""
    private var currentCandidates: [InputEngine.Candidate] = []
    private var isBopomofoMode = false  // 是否為注音模式（已棄用，使用智能檢測）
    
    /// 系統事件處理器
    private var eventHandler: EventHandlerRef?
    
    // MARK: - Initialization
    
    override init() {
        self.inputEngine = InputEngine()
        self.smartEngine = SmartInputEngine()  // 初始化智能引擎
        super.init()
        setupEventHandling()
        
        print("🎯 智能輸入引擎已初始化")
    }
    
    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
    
    // MARK: - Setup
    
    private func setupEventHandling() {
        // 設置鍵盤事件監聽
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventRawKeyDown))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let server = Unmanaged<InputMethodServer>.fromOpaque(userData!).takeUnretainedValue() as InputMethodServer? else {
                    return OSStatus(eventNotHandledErr)
                }
                return server.handleKeyboardEvent(nextHandler, theEvent)
            },
            1,
            [eventSpec],
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status != noErr {
            print("❌ 無法設置事件處理器: \(status)")
        }
    }
    
    // MARK: - Event Handling
    
    private func handleKeyboardEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?) -> OSStatus {
        guard let event = theEvent else { return OSStatus(eventNotHandledErr) }
        
        var keyCode: UInt32 = 0
        var modifiers: UInt32 = 0
        
        GetEventParameter(event, OSType(kEventParamKeyCode), typeUInt32, nil, MemoryLayout<UInt32>.size, nil, &keyCode)
        GetEventParameter(event, OSType(kEventParamKeyModifiers), typeUInt32, nil, MemoryLayout<UInt32>.size, nil, &modifiers)
        
        // 檢查是否為輸入法切換快捷鍵
        if isInputMethodToggleKey(keyCode: keyCode, modifiers: modifiers) {
            toggleInputMethod()
            return noErr
        }
        
        // 處理輸入
        if isInputting {
            return handleInputKey(keyCode: keyCode, modifiers: modifiers)
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    private func isInputMethodToggleKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // 檢查是否為 Cmd+Space 或其他切換快捷鍵
        let cmdKey = modifiers & UInt32(cmdKey)
        return cmdKey != 0 && keyCode == 49 // Space key
    }
    
    private func handleInputKey(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        // 檢查是否為模式切換快捷鍵 (Cmd+Shift+M)
        let cmdKey = modifiers & UInt32(cmdKey)
        let shiftKey = modifiers & UInt32(shiftKey)
        
        if cmdKey != 0 && shiftKey != 0 && keyCode == 46 { // M key
            toggleInputMode()
            return noErr
        }
        
        // 處理輸入鍵
        let key = keyCodeToString(keyCode: keyCode, modifiers: modifiers)
        
        if let key = key {
            processInput(key)
        }
        
        return noErr
    }
    
    private func toggleInputMode() {
        isBopomofoMode.toggle()
        let mode = isBopomofoMode ? "注音" : "英文"
        print("🔄 手動切換到\(mode)模式")
        
        // 重新生成候選詞
        generateCandidates()
    }
    
    private func keyCodeToString(keyCode: UInt32, modifiers: UInt32) -> String? {
        // 將鍵碼轉換為字符
        let shiftKey = modifiers & UInt32(shiftKey)
        let _ = modifiers & UInt32(alphaLock)
        
        switch keyCode {
        case 0: return shiftKey != 0 ? "A" : "a"
        case 1: return shiftKey != 0 ? "S" : "s"
        case 2: return shiftKey != 0 ? "D" : "d"
        case 3: return shiftKey != 0 ? "F" : "f"
        case 4: return shiftKey != 0 ? "H" : "h"
        case 5: return shiftKey != 0 ? "G" : "g"
        case 6: return shiftKey != 0 ? "Z" : "z"
        case 7: return shiftKey != 0 ? "X" : "x"
        case 8: return shiftKey != 0 ? "C" : "c"
        case 9: return shiftKey != 0 ? "V" : "v"
        case 11: return shiftKey != 0 ? "B" : "b"
        case 12: return shiftKey != 0 ? "Q" : "q"
        case 13: return shiftKey != 0 ? "W" : "w"
        case 14: return shiftKey != 0 ? "E" : "e"
        case 15: return shiftKey != 0 ? "R" : "r"
        case 16: return shiftKey != 0 ? "Y" : "y"
        case 17: return shiftKey != 0 ? "T" : "t"
        case 18: return shiftKey != 0 ? "1" : "1"
        case 19: return shiftKey != 0 ? "2" : "2"
        case 20: return shiftKey != 0 ? "3" : "3"
        case 21: return shiftKey != 0 ? "4" : "4"
        case 22: return shiftKey != 0 ? "6" : "6"
        case 23: return shiftKey != 0 ? "5" : "5"
        case 24: return shiftKey != 0 ? "=" : "="
        case 25: return shiftKey != 0 ? "9" : "9"
        case 26: return shiftKey != 0 ? "7" : "7"
        case 27: return shiftKey != 0 ? "-" : "-"
        case 28: return shiftKey != 0 ? "8" : "8"
        case 29: return shiftKey != 0 ? "0" : "0"
        case 30: return shiftKey != 0 ? "]" : "]"
        case 31: return shiftKey != 0 ? "O" : "o"
        case 32: return shiftKey != 0 ? "U" : "u"
        case 33: return shiftKey != 0 ? "[" : "["
        case 34: return shiftKey != 0 ? "I" : "i"
        case 35: return shiftKey != 0 ? "P" : "p"
        case 36: return "return"
        case 37: return shiftKey != 0 ? "L" : "l"
        case 38: return shiftKey != 0 ? "J" : "j"
        case 39: return shiftKey != 0 ? "'" : "'"
        case 40: return shiftKey != 0 ? "K" : "k"
        case 41: return shiftKey != 0 ? ";" : ";"
        case 42: return shiftKey != 0 ? "\\" : "\\"
        case 43: return shiftKey != 0 ? "," : ","
        case 44: return shiftKey != 0 ? "/" : "/"
        case 45: return shiftKey != 0 ? "N" : "n"
        case 46: return shiftKey != 0 ? "M" : "m"
        case 47: return shiftKey != 0 ? "." : "."
        case 48: return "tab"
        case 49: return " "
        case 51: return "delete"
        case 53: return "escape"
        default:
            return nil
        }
    }
    
    // MARK: - Input Processing
    
    private func processInput(_ input: String) {
        if input == "escape" {
            cancelInput()
            return
        }
        
        if input == "return" {
            confirmInput()
            return
        }
        
        if input == "delete" {
            deleteLastCharacter()
            return
        }
        
        if input == " " {
            // 空格鍵處理
            if !currentInput.isEmpty {
                generateCandidates()
            }
            return
        }
        
        // 添加字符到輸入緩衝
        currentInput += input
        
        // 使用智能引擎處理輸入
        processWithSmartEngine()
    }
    
    /// 使用智能引擎處理輸入（新方法）
    private func processWithSmartEngine() {
        // 使用 SmartInputEngine 處理輸入
        let result = smartEngine.processInput(currentInput)
        
        // 更新輸入模式（基於智能檢測）
        switch result.type {
        case .bopomofo:
            if !isBopomofoMode {
                isBopomofoMode = true
                print("🔄 智能檢測：切換到注音模式")
            }
        case .english:
            if isBopomofoMode {
                isBopomofoMode = false
                print("🔄 智能檢測：切換到英文模式")
            }
        case .unknown:
            print("⚠️  未知輸入類型")
        }
        
        // 顯示檢測信息
        print("📝 輸入: \(result.originalInput)")
        print("🔤 注音: \(result.bopomofoSequence)")
        print("🎯 輸出: \(result.output)")
        print("💯 信心度: \(Int(result.confidence * 100))%")
        
        // 轉換候選詞格式並顯示
        currentCandidates = result.candidates.map { candidateText in
            InputEngine.Candidate(
                text: candidateText,
                score: result.confidence,
                source: result.type == .bopomofo ? .bopomofoConversion : .englishCompletion
            )
        }
        
        // 顯示候選詞窗口
        updateCandidateWindow()
    }
    
    private func detectInputType() {
        // 智能檢測輸入類型
        let inputType = detectSmartInputType(currentInput)
        
        if inputType == .bopomofo && !isBopomofoMode {
            // 切換到注音模式
            isBopomofoMode = true
            print("🔄 自動切換到注音模式")
        } else if inputType == .english && isBopomofoMode {
            // 切換到英文模式
            isBopomofoMode = false
            print("🔄 自動切換到英文模式")
        }
    }
    
    private enum InputType {
        case english
        case bopomofo
        case ambiguous
    }
    
    private func detectSmartInputType(_ input: String) -> InputType {
        // 1. 檢查是否為純注音符號
        let isPureBopomofo = isBopomofoInput(input)
        
        // 2. 檢查是否為純英文字母
        let isPureEnglish = isEnglishInput(input)
        
        // 3. 檢查是否為混合輸入
        let hasMixedChars = hasMixedCharacters(input)
        
        if isPureBopomofo && !hasMixedChars {
            return .bopomofo
        } else if isPureEnglish && !hasMixedChars {
            return .english
        } else if hasMixedChars {
            // 混合輸入時，根據主要字符類型判斷
            let bopomofoCount = input.filter { isBopomofoCharacter($0) }.count
            let englishCount = input.filter { isEnglishCharacter($0) }.count
            
            if bopomofoCount > englishCount {
                return .bopomofo
            } else if englishCount > bopomofoCount {
                return .english
            } else {
                return .ambiguous
            }
        } else {
            // 其他情況，保持當前模式
            return isBopomofoMode ? .bopomofo : .english
        }
    }
    
    private func isEnglishInput(_ input: String) -> Bool {
        let englishPattern = "^[a-zA-Z]+$"
        let regex = try? NSRegularExpression(pattern: englishPattern)
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex?.firstMatch(in: input, options: [], range: range) != nil
    }
    
    private func hasMixedCharacters(_ input: String) -> Bool {
        let hasBopomofo = input.contains { isBopomofoCharacter($0) }
        let hasEnglish = input.contains { isEnglishCharacter($0) }
        return hasBopomofo && hasEnglish
    }
    
    private func isBopomofoCharacter(_ char: Character) -> Bool {
        let bopomofoRange = "ㄅ"..."ㄩ"
        return bopomofoRange.contains(String(char))
    }
    
    private func isEnglishCharacter(_ char: Character) -> Bool {
        return char.isLetter && char.isASCII
    }
    
    private func isBopomofoInput(_ input: String) -> Bool {
        // 檢測是否為注音符號
        let bopomofoPattern = "^[ㄅ-ㄩ]+$"
        let regex = try? NSRegularExpression(pattern: bopomofoPattern)
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex?.firstMatch(in: input, options: [], range: range) != nil
    }
    
    private func generateCandidates() {
        if isBopomofoMode {
            // 注音模式：生成中文候選詞
            inputEngine.handleInputAsync(currentInput) { [weak self] candidates in
                DispatchQueue.main.async {
                    self?.currentCandidates = candidates
                    self?.updateCandidateWindow()
                }
            }
        } else {
            // 英文模式：生成英文候選詞
            generateEnglishCandidates()
        }
    }
    
    private func generateEnglishCandidates() {
        // 智能英文候選詞生成
        var englishCandidates: [InputEngine.Candidate] = []
        
        // 1. 如果輸入看起來像英文單字，提供拼寫建議
        if isLikelyEnglishWord(currentInput) {
            let suggestions = getEnglishWordSuggestions(currentInput)
            englishCandidates.append(contentsOf: suggestions)
        }
        
        // 2. 如果沒有找到建議，提供通用建議
        if englishCandidates.isEmpty {
            let generalSuggestions = inputEngine.getSuggestions(limit: 5).map { word in
                InputEngine.Candidate(text: word, score: 0.8, source: .englishCompletion)
            }
            englishCandidates.append(contentsOf: generalSuggestions)
        }
        
        // 3. 如果還是沒有建議，提供原始輸入
        if englishCandidates.isEmpty {
            englishCandidates.append(InputEngine.Candidate(text: currentInput, score: 1.0, source: .englishCompletion))
        }
        
        currentCandidates = englishCandidates
        updateCandidateWindow()
    }
    
    private func isLikelyEnglishWord(_ input: String) -> Bool {
        // 檢查是否看起來像英文單字
        return input.count >= 2 && input.allSatisfy { $0.isLetter }
    }
    
    private func getEnglishWordSuggestions(_ input: String) -> [InputEngine.Candidate] {
        // 簡單的拼寫建議算法
        let suggestions = [
            // 常見的拼寫錯誤修正
            "hello": ["hello", "helo", "hallo"],
            "world": ["world", "word", "would"],
            "programming": ["programming", "programing", "program"],
            "computer": ["computer", "computor", "comuter"],
            "language": ["language", "langauge", "languge"],
            "development": ["development", "developement", "develop"],
            "technology": ["technology", "technolgy", "tech"],
            "application": ["application", "aplication", "app"],
            "interface": ["interface", "interfce", "inter"],
            "function": ["function", "funtion", "func"]
        ]
        
        let lowercased = input.lowercased()
        if let wordSuggestions = suggestions[lowercased] {
            return wordSuggestions.map { word in
                InputEngine.Candidate(text: word, score: 1.0, source: .englishCompletion)
            }
        }
        
        // 模糊匹配
        return findSimilarWords(input, in: Array(suggestions.keys))
    }
    
    private func findSimilarWords(_ input: String, in words: [String]) -> [InputEngine.Candidate] {
        let inputLower = input.lowercased()
        var candidates: [(String, Double)] = []
        
        for word in words {
            let similarity = calculateSimilarity(inputLower, word)
            if similarity > 0.6 { // 相似度閾值
                candidates.append((word, similarity))
            }
        }
        
        return candidates
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { InputEngine.Candidate(text: $0.0, score: $0.1, source: .englishCompletion) }
    }
    
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        // 簡單的編輯距離相似度計算
        let len1 = s1.count
        let len2 = s2.count
        
        if len1 == 0 { return len2 == 0 ? 1.0 : 0.0 }
        if len2 == 0 { return 0.0 }
        
        let maxLen = max(len1, len2)
        let distance = levenshteinDistance(s1, s2)
        
        return 1.0 - Double(distance) / Double(maxLen)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    private func updateCandidateWindow() {
        if candidateWindow == nil {
            candidateWindow = CandidateWindow()
        }
        
        candidateWindow?.updateCandidates(currentCandidates, input: currentInput, isBopomofoMode: isBopomofoMode)
        candidateWindow?.show()
    }
    
    private func cancelInput() {
        currentInput = ""
        currentCandidates = []
        isBopomofoMode = false
        candidateWindow?.hide()
        isInputting = false
    }
    
    private func confirmInput() {
        if let firstCandidate = currentCandidates.first {
            insertText(firstCandidate.text)
        } else if !currentInput.isEmpty {
            insertText(currentInput)
        }
        
        cancelInput()
    }
    
    private func deleteLastCharacter() {
        if !currentInput.isEmpty {
            currentInput.removeLast()
            detectInputType()  // 重新檢測輸入類型
            generateCandidates()
        }
    }
    
    private func insertText(_ text: String) {
        // 插入文字到當前應用程式
        let source = CGEventSource(stateID: .hidSystemState)
        let _ = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        
        // 這裡需要實際的文字插入邏輯
        print("插入文字: \(text)")
    }
    
    // MARK: - Input Method Control
    
    private func toggleInputMethod() {
        isInputting.toggle()
        
        if isInputting {
            print("🔄 切換到智能輸入法 (預設英文模式)")
            currentInput = ""
            isBopomofoMode = false
        } else {
            print("🔄 切換到系統輸入法")
            cancelInput()
        }
    }
    
    // MARK: - Public Interface
    
    func start() {
        print("🚀 啟動智能輸入法服務")
        isInputting = true
    }
    
    func stop() {
        print("⏹️ 停止智能輸入法服務")
        isInputting = false
        cancelInput()
    }
}

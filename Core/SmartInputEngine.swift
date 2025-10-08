import Foundation

/// 智能輸入引擎
/// 核心邏輯：先檢查是否為有效注音序列，再決定輸出
/// 基於 truly_smart_input.swift 的驗證邏輯
class SmartInputEngine {
    
    // 核心組件
    private let keyboardMapper: KeyboardMapper
    private let dictionaryLookup: DictionaryLookup
    
    // 常見英文單字列表（用於判斷是否為英文）
    private let englishWords: Set<String> = [
        "hello", "world", "programming", "test", "code", "swift",
        "apple", "macos", "input", "method", "keyboard", "typing",
        "computer", "software", "development", "application", "system",
        "user", "interface", "design", "function", "variable", "class"
    ]
    
    /// 初始化
    init() {
        self.keyboardMapper = KeyboardMapper()
        self.dictionaryLookup = DictionaryLookup()
    }
    
    /// 初始化（自定義組件）
    init(keyboardMapper: KeyboardMapper, dictionaryLookup: DictionaryLookup) {
        self.keyboardMapper = keyboardMapper
        self.dictionaryLookup = dictionaryLookup
    }
    
    /// 處理輸入（核心方法）
    /// - Parameter input: 英文鍵盤輸入
    /// - Returns: 輸入結果
    func processInput(_ input: String) -> InputResult {
        // 步驟 1: 轉換為注音序列
        let bopomofoSequence = keyboardMapper.convert(input)
        
        // 步驟 2: 檢查是否為有效注音
        if let candidates = dictionaryLookup.lookup(bopomofoSequence) {
            // 是有效注音 → 輸出中文
            return InputResult(
                originalInput: input,
                bopomofoSequence: bopomofoSequence,
                output: candidates.first ?? input,
                type: .bopomofo,
                candidates: candidates,
                confidence: 0.95
            )
        }
        
        // 步驟 3: 不是有效注音 → 檢查是否為英文
        if isEnglishWord(input) {
            // 是英文 → 保持英文
            return InputResult(
                originalInput: input,
                bopomofoSequence: bopomofoSequence,
                output: input,
                type: .english,
                candidates: [input],
                confidence: 0.90
            )
        }
        
        // 未知輸入
        return InputResult(
            originalInput: input,
            bopomofoSequence: bopomofoSequence,
            output: input,
            type: .unknown,
            candidates: [input],
            confidence: 0.50
        )
    }
    
    /// 批量處理輸入（處理空格分隔的多個詞）
    /// - Parameter input: 英文鍵盤輸入（可能包含空格）
    /// - Returns: 處理結果列表
    func processBatch(_ input: String) -> [InputResult] {
        let parts = input.split(separator: " ")
        return parts.map { processInput(String($0)) }
    }
    
    /// 檢查是否為英文單字
    private func isEnglishWord(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        
        // 檢查是否為已知英文單字
        if englishWords.contains(lowercased) {
            return true
        }
        
        // 檢查是否只包含英文字母
        let hasOnlyEnglish = input.allSatisfy { $0.isLetter && $0.isASCII }
        
        return hasOnlyEnglish
    }
    
    /// 獲取候選詞（用於 UI 顯示）
    /// - Parameter input: 英文鍵盤輸入
    /// - Returns: 候選詞列表
    func getCandidates(_ input: String) -> [String] {
        let result = processInput(input)
        return result.candidates
    }
}

// MARK: - 數據結構

/// 輸入結果
struct InputResult {
    /// 原始輸入（英文鍵盤）
    let originalInput: String
    
    /// 注音序列
    let bopomofoSequence: String
    
    /// 輸出結果（中文或英文）
    let output: String
    
    /// 輸入類型
    let type: InputType
    
    /// 候選詞列表
    let candidates: [String]
    
    /// 信心度（0.0 - 1.0）
    let confidence: Double
    
    /// 輸入類型
    enum InputType {
        case bopomofo   // 注音輸入
        case english    // 英文輸入
        case unknown    // 未知輸入
    }
    
    /// 描述
    var description: String {
        switch type {
        case .bopomofo:
            return "注音輸入"
        case .english:
            return "英文輸入"
        case .unknown:
            return "未知輸入"
        }
    }
}

// MARK: - 使用範例

/*
let engine = SmartInputEngine()

// 範例 1: 注音輸入
let result1 = engine.processInput("su3cl3")
print("\(result1.originalInput) → \(result1.output)")  // su3cl3 → 你好
print("類型: \(result1.description)")  // 類型: 注音輸入
print("信心度: \(result1.confidence)")  // 信心度: 0.95

// 範例 2: 英文輸入
let result2 = engine.processInput("hello")
print("\(result2.originalInput) → \(result2.output)")  // hello → hello
print("類型: \(result2.description)")  // 類型: 英文輸入

// 範例 3: 長句子
let result3 = engine.processInput("rup wu0 wu0 fu45p cl3")
print("\(result3.originalInput) → \(result3.output)")  // rup wu0 wu0 fu45p cl3 → 今
print("完整候選: \(result3.candidates)")  // ["今", "天", "天", "氣真", "好"]

// 範例 4: 批量處理
let results = engine.processBatch("su3cl3 hello j3")
for result in results {
    print("\(result.originalInput) → \(result.output)")
}
// su3cl3 → 你好
// hello → hello
// j3 → 我
*/

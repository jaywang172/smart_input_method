import Foundation

/// 語言檢測器 - 自動判斷使用者輸入的是中文還是英文
class LanguageDetector {
    
    /// 支援的語言類型
    enum Language {
        case chinese
        case english
        case mixed
        case unknown
    }
    
    /// 檢測結果
    struct DetectionResult {
        let language: Language
        let confidence: Double  // 0.0 - 1.0
        let features: [String: Double]
    }
    
    // 英文常見單詞（用於判斷）
    private let commonEnglishWords: Set<String> = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
        "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
        "or", "an", "will", "my", "one", "all", "would", "there", "their", "what"
    ]
    
    // 注音符號集合
    private let bopomofoChars: Set<Character> = [
        "ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄉ", "ㄊ", "ㄋ", "ㄌ", "ㄍ", "ㄎ", "ㄏ",
        "ㄐ", "ㄑ", "ㄒ", "ㄓ", "ㄔ", "ㄕ", "ㄖ", "ㄗ", "ㄘ", "ㄙ",
        "ㄧ", "ㄨ", "ㄩ", "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ", "ㄠ", "ㄡ",
        "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ",
        "ˊ", "ˇ", "ˋ", "˙"
    ]
    
    // 使用者歷史記錄（用於個性化預測）
    private var userHistory: [Language] = []
    private let maxHistorySize = 100
    
    init() {}
    
    /// 檢測輸入字串的語言
    /// - Parameters:
    ///   - input: 輸入字串
    ///   - context: 上下文字串（前面已輸入的內容）
    /// - Returns: 檢測結果
    func detect(_ input: String, context: String = "") -> DetectionResult {
        let features = extractFeatures(input, context: context)
        let language = classifyLanguage(features)
        let confidence = calculateConfidence(features, predictedLanguage: language)
        
        // 更新使用者歷史
        updateHistory(language)
        
        return DetectionResult(language: language, confidence: confidence, features: features)
    }
    
    /// 提取特徵
    private func extractFeatures(_ input: String, context: String) -> [String: Double] {
        var features: [String: Double] = [:]
        
        // 特徵 1: 注音符號比例
        let bopomofoRatio = calculateBopomofoRatio(input)
        features["bopomofo_ratio"] = bopomofoRatio
        
        // 特徵 2: ASCII 字母比例
        let asciiRatio = calculateAsciiRatio(input)
        features["ascii_ratio"] = asciiRatio
        
        // 特徵 3: 中文字符比例
        let chineseRatio = calculateChineseCharRatio(input)
        features["chinese_ratio"] = chineseRatio
        
        // 特徵 4: 數字比例
        let digitRatio = calculateDigitRatio(input)
        features["digit_ratio"] = digitRatio
        
        // 特徵 5: 英文單詞匹配度
        let englishWordMatch = checkEnglishWordMatch(input)
        features["english_word_match"] = englishWordMatch
        
        // 特徵 6: 上下文語言
        let contextLanguage = detectContextLanguage(context)
        features["context_language"] = contextLanguage
        
        // 特徵 7: 使用者偏好（基於歷史）
        let userPreference = calculateUserPreference()
        features["user_preference_chinese"] = userPreference.chinese
        features["user_preference_english"] = userPreference.english
        
        // 特徵 8: 字串長度（短字串更可能是英文）
        features["length_score"] = min(Double(input.count) / 10.0, 1.0)
        
        return features
    }
    
    /// 分類語言
    private func classifyLanguage(_ features: [String: Double]) -> Language {
        let bopomofoRatio = features["bopomofo_ratio"] ?? 0.0
        let asciiRatio = features["ascii_ratio"] ?? 0.0
        let chineseRatio = features["chinese_ratio"] ?? 0.0
        let englishWordMatch = features["english_word_match"] ?? 0.0
        let contextLanguage = features["context_language"] ?? 0.5
        
        // 規則1: 如果有注音符號，很可能是中文
        if bopomofoRatio > 0.3 {
            return .chinese
        }
        
        // 規則2: 如果全是 ASCII 且匹配英文單詞，是英文
        if asciiRatio > 0.8 && englishWordMatch > 0.5 {
            return .english
        }
        
        // 規則3: 如果有中文字符，是中文
        if chineseRatio > 0.3 {
            return .chinese
        }
        
        // 規則4: 根據上下文判斷
        if contextLanguage > 0.7 {
            return .chinese
        } else if contextLanguage < 0.3 {
            return .english
        }
        
        // 規則5: 使用加權評分
        let chineseScore = bopomofoRatio * 2.0 + chineseRatio * 2.0 + contextLanguage
        let englishScore = asciiRatio * 1.5 + englishWordMatch * 1.5 + (1.0 - contextLanguage)
        
        if chineseScore > englishScore {
            return chineseScore > 1.0 ? .chinese : .mixed
        } else {
            return englishScore > 1.0 ? .english : .mixed
        }
    }
    
    /// 計算信心度
    private func calculateConfidence(_ features: [String: Double], predictedLanguage: Language) -> Double {
        switch predictedLanguage {
        case .chinese:
            let bopomofo = features["bopomofo_ratio"] ?? 0.0
            let chinese = features["chinese_ratio"] ?? 0.0
            return min((bopomofo + chinese) / 2.0 * 1.5, 1.0)
            
        case .english:
            let ascii = features["ascii_ratio"] ?? 0.0
            let englishMatch = features["english_word_match"] ?? 0.0
            return min((ascii + englishMatch) / 2.0 * 1.5, 1.0)
            
        case .mixed:
            return 0.5
            
        case .unknown:
            return 0.0
        }
    }
    
    // MARK: - Feature Extraction Methods
    
    private func calculateBopomofoRatio(_ str: String) -> Double {
        guard !str.isEmpty else { return 0.0 }
        let bopomofoCount = str.filter { bopomofoChars.contains($0) }.count
        return Double(bopomofoCount) / Double(str.count)
    }
    
    private func calculateAsciiRatio(_ str: String) -> Double {
        guard !str.isEmpty else { return 0.0 }
        let asciiCount = str.filter { $0.isASCII && $0.isLetter }.count
        return Double(asciiCount) / Double(str.count)
    }
    
    private func calculateChineseCharRatio(_ str: String) -> Double {
        guard !str.isEmpty else { return 0.0 }
        let chineseCount = str.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }.count
        return Double(chineseCount) / Double(str.count)
    }
    
    private func calculateDigitRatio(_ str: String) -> Double {
        guard !str.isEmpty else { return 0.0 }
        let digitCount = str.filter { $0.isNumber }.count
        return Double(digitCount) / Double(str.count)
    }
    
    private func checkEnglishWordMatch(_ str: String) -> Double {
        let words = str.lowercased().components(separatedBy: .whitespaces)
        guard !words.isEmpty else { return 0.0 }
        
        let matchCount = words.filter { commonEnglishWords.contains($0) }.count
        return Double(matchCount) / Double(words.count)
    }
    
    private func detectContextLanguage(_ context: String) -> Double {
        let chineseRatio = calculateChineseCharRatio(context)
        let bopomofoRatio = calculateBopomofoRatio(context)
        
        return (chineseRatio + bopomofoRatio) / 2.0
    }
    
    private func calculateUserPreference() -> (chinese: Double, english: Double) {
        guard !userHistory.isEmpty else { return (0.5, 0.5) }
        
        let chineseCount = userHistory.filter { $0 == .chinese }.count
        let englishCount = userHistory.filter { $0 == .english }.count
        let total = userHistory.count
        
        return (
            chinese: Double(chineseCount) / Double(total),
            english: Double(englishCount) / Double(total)
        )
    }
    
    private func updateHistory(_ language: Language) {
        userHistory.append(language)
        
        if userHistory.count > maxHistorySize {
            userHistory.removeFirst()
        }
    }
    
    /// 清除使用者歷史
    func clearHistory() {
        userHistory.removeAll()
    }
}

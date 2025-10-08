import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// 基於機器學習的語言分類器
/// 使用特徵工程和簡單的分類演算法
class LanguageClassifier {
    
    /// 分類結果
    struct ClassificationResult {
        let language: LanguageType
        let probability: Double
        let allProbabilities: [LanguageType: Double]
    }
    
    enum LanguageType: String {
        case chinese = "中文"
        case english = "英文"
    }
    
    // 樸素貝葉斯分類器參數
    private var featureWeights: [String: [LanguageType: Double]] = [:]
    private var priorProbabilities: [LanguageType: Double] = [
        .chinese: 0.5,
        .english: 0.5
    ]
    
    // 訓練數據統計
    private var trainingStats: [LanguageType: Int] = [:]
    
    init() {
        initializeDefaultWeights()
    }
    
    /// 初始化預設權重
    private func initializeDefaultWeights() {
        // 基於經驗的初始權重
        featureWeights = [
            "has_bopomofo": [.chinese: 0.95, .english: 0.05],
            "has_chinese_chars": [.chinese: 0.90, .english: 0.10],
            "has_ascii_letters": [.chinese: 0.20, .english: 0.80],
            "avg_char_length": [.chinese: 0.60, .english: 0.40],
            "has_spaces": [.chinese: 0.30, .english: 0.70],
            "numeric_ratio": [.chinese: 0.50, .english: 0.50],
        ]
    }
    
    /// 分類輸入文本
    /// - Parameter input: 輸入字串
    /// - Returns: 分類結果
    func classify(_ input: String) -> ClassificationResult {
        let features = extractFeatures(from: input)
        let probabilities = calculateProbabilities(features)
        
        // 找出機率最高的語言
        let maxLanguage = probabilities.max { $0.value < $1.value }?.key ?? .english
        let maxProbability = probabilities[maxLanguage] ?? 0.5
        
        return ClassificationResult(
            language: maxLanguage,
            probability: maxProbability,
            allProbabilities: probabilities
        )
    }
    
    /// 提取特徵向量
    private func extractFeatures(from input: String) -> [String: Double] {
        var features: [String: Double] = [:]
        
        // 特徵1: 是否包含注音符號
        features["has_bopomofo"] = containsBopomofo(input) ? 1.0 : 0.0
        
        // 特徵2: 是否包含中文字符
        features["has_chinese_chars"] = containsChineseChars(input) ? 1.0 : 0.0
        
        // 特徵3: 是否包含 ASCII 字母
        features["has_ascii_letters"] = containsAsciiLetters(input) ? 1.0 : 0.0
        
        // 特徵4: 平均字符長度（bytes）
        let avgLength = Double(input.utf8.count) / Double(input.count)
        features["avg_char_length"] = min(avgLength / 3.0, 1.0)  // 正規化到 0-1
        
        // 特徵5: 是否包含空格
        features["has_spaces"] = input.contains(" ") ? 1.0 : 0.0
        
        // 特徵6: 數字比例
        let digitCount = input.filter { $0.isNumber }.count
        features["numeric_ratio"] = Double(digitCount) / Double(max(input.count, 1))
        
        return features
    }
    
    /// 計算各語言的機率
    private func calculateProbabilities(_ features: [String: Double]) -> [LanguageType: Double] {
        var probabilities: [LanguageType: Double] = [:]
        
        for language in [LanguageType.chinese, LanguageType.english] {
            var logProb = log(priorProbabilities[language] ?? 0.5)
            
            for (featureName, featureValue) in features {
                if let weights = featureWeights[featureName],
                   let weight = weights[language] {
                    // 使用特徵值和權重計算
                    let contribution = featureValue * weight + (1.0 - featureValue) * (1.0 - weight)
                    logProb += log(max(contribution, 0.01))  // 避免 log(0)
                }
            }
            
            probabilities[language] = exp(logProb)
        }
        
        // 正規化機率
        let total = probabilities.values.reduce(0, +)
        if total > 0 {
            for language in probabilities.keys {
                probabilities[language]! /= total
            }
        }
        
        return probabilities
    }
    
    // MARK: - Training
    
    /// 訓練分類器
    /// - Parameter samples: 訓練樣本 [(文本, 語言)]
    func train(samples: [(String, LanguageType)]) {
        guard !samples.isEmpty else { return }
        
        // 統計每種語言的樣本數
        var languageCounts: [LanguageType: Int] = [:]
        var featureStats: [String: [LanguageType: [Double]]] = [:]
        
        for (text, language) in samples {
            languageCounts[language, default: 0] += 1
            
            let features = extractFeatures(from: text)
            for (featureName, featureValue) in features {
                if featureStats[featureName] == nil {
                    featureStats[featureName] = [:]
                }
                if featureStats[featureName]![language] == nil {
                    featureStats[featureName]![language] = []
                }
                featureStats[featureName]![language]!.append(featureValue)
            }
        }
        
        // 更新先驗機率
        let totalSamples = samples.count
        for (language, count) in languageCounts {
            priorProbabilities[language] = Double(count) / Double(totalSamples)
        }
        
        // 更新特徵權重（使用平均值）
        for (featureName, languageValues) in featureStats {
            featureWeights[featureName] = [:]
            for (language, values) in languageValues {
                let average = values.reduce(0, +) / Double(values.count)
                featureWeights[featureName]![language] = average
            }
        }
        
        trainingStats = languageCounts
    }
    
    /// 增量學習
    func learn(text: String, correctLanguage: LanguageType) {
        let features = extractFeatures(from: text)
        let learningRate = 0.1
        
        // 更新特徵權重
        for (featureName, featureValue) in features {
            if featureWeights[featureName] == nil {
                featureWeights[featureName] = [:]
            }
            
            for language in [LanguageType.chinese, LanguageType.english] {
                let currentWeight = featureWeights[featureName]![language] ?? 0.5
                
                if language == correctLanguage {
                    // 增加正確語言的權重
                    let newWeight = currentWeight + learningRate * (featureValue - currentWeight)
                    featureWeights[featureName]![language] = min(max(newWeight, 0.0), 1.0)
                } else {
                    // 減少錯誤語言的權重
                    let newWeight = currentWeight - learningRate * (featureValue - currentWeight)
                    featureWeights[featureName]![language] = min(max(newWeight, 0.0), 1.0)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func containsBopomofo(_ str: String) -> Bool {
        let bopomofoRange = Unicode.Scalar(0x3105)!...Unicode.Scalar(0x312F)!
        return str.unicodeScalars.contains { bopomofoRange.contains($0) }
    }
    
    private func containsChineseChars(_ str: String) -> Bool {
        let chineseRange = Unicode.Scalar(0x4E00)!...Unicode.Scalar(0x9FFF)!
        return str.unicodeScalars.contains { chineseRange.contains($0) }
    }
    
    private func containsAsciiLetters(_ str: String) -> Bool {
        return str.contains { $0.isASCII && $0.isLetter }
    }
    
    // MARK: - Model Persistence
    
    /// 保存模型
    func saveModel(to path: String) throws {
        let model: [String: Any] = [
            "feature_weights": featureWeights.mapValues { dict in
                dict.mapKeys { $0.rawValue }
            },
            "prior_probabilities": priorProbabilities.mapKeys { $0.rawValue },
            "training_stats": trainingStats.mapKeys { $0.rawValue }
        ]
        
        let data = try JSONSerialization.data(withJSONObject: model, options: .prettyPrinted)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    /// 加載模型
    func loadModel(from path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LanguageClassifier", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid model file"])
        }
        
        // 加載特徵權重
        if let weights = json["feature_weights"] as? [String: [String: Double]] {
            featureWeights = weights.mapValues { dict in
                dict.compactMapKeys { LanguageType(rawValue: $0) }
            }
        }
        
        // 加載先驗機率
        if let priors = json["prior_probabilities"] as? [String: Double] {
            priorProbabilities = priors.compactMapKeys { LanguageType(rawValue: $0) }
        }
        
        // 加載訓練統計
        if let stats = json["training_stats"] as? [String: Int] {
            trainingStats = stats.compactMapKeys { LanguageType(rawValue: $0) }
        }
    }
    
    /// 獲取模型資訊
    func getModelInfo() -> [String: Any] {
        return [
            "feature_count": featureWeights.count,
            "training_samples": trainingStats,
            "prior_probabilities": priorProbabilities.mapKeys { $0.rawValue }
        ]
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
    
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}

import Foundation

/// 規則檢測 + 分類器融合，輸出最終語言與信心
final class LanguageDetectionFusion {
    struct Result {
        let language: LanguageDetector.Language
        let confidence: Double
    }

    private let ruleDetector: LanguageDetector
    private let classifier: LanguageClassifier
    // 自適應參數
    private var ruleThreshold: Double = 0.8
    private var ruleWeight: Double = 0.6
    private var classifierWeight: Double = 0.6
    private let learningRate: Double = 0.01
    private let queue = DispatchQueue(label: "LanguageDetectionFusion", attributes: .concurrent)

    init(ruleDetector: LanguageDetector = LanguageDetector(), classifier: LanguageClassifier = LanguageClassifier()) {
        self.ruleDetector = ruleDetector
        self.classifier = classifier
    }

    func detect(_ input: String, context: [String]) -> Result {
        let rule = ruleDetector.detect(input, context: context.joined(separator: " "))
        let cls = classifier.classify(input)
        // 簡單融合：當規則信心高時信任規則；否則用分類器概率決策
        if rule.confidence >= ruleThreshold {
            return Result(language: rule.language, confidence: rule.confidence)
        }
        // 映射分類器類型到最終語言
        let clsLang: LanguageDetector.Language = (cls.language == .chinese) ? .chinese : .english
        // 若規則與分類器一致，提升信心；否則取分類器並降低信心
        if clsLang == rule.language {
            let conf = min(1.0, (rule.confidence * ruleWeight) + (cls.probability * classifierWeight))
            return Result(language: clsLang, confidence: conf)
        } else {
            let conf = max(0.5, cls.probability * 0.7)
            // 若規則判為混合，優先採用分類器語言
            let finalLang: LanguageDetector.Language = (rule.language == .mixed) ? clsLang : clsLang
            return Result(language: finalLang, confidence: conf)
        }
    }

    /// 線上學習：根據用戶反饋調整權重
    func learnFromFeedback(_ input: String, correctLanguage: LanguageDetector.Language) {
        queue.async(flags: .barrier) {
            let rule = self.ruleDetector.detect(input, context: "")
            let cls = self.classifier.classify(input)
            let clsLang: LanguageDetector.Language = (cls.language == .chinese) ? .chinese : .english
            
            // 調整規則權重
            if rule.language == correctLanguage {
                self.ruleWeight = min(1.0, self.ruleWeight + self.learningRate)
            } else {
                self.ruleWeight = max(0.1, self.ruleWeight - self.learningRate)
            }
            
            // 調整分類器權重
            if clsLang == correctLanguage {
                self.classifierWeight = min(1.0, self.classifierWeight + self.learningRate)
            } else {
                self.classifierWeight = max(0.1, self.classifierWeight - self.learningRate)
            }
            
            // 動態調整規則門檻
            if rule.confidence > 0.5 && rule.language == correctLanguage {
                self.ruleThreshold = min(0.95, self.ruleThreshold + self.learningRate * 0.5)
            } else if rule.confidence > 0.5 && rule.language != correctLanguage {
                self.ruleThreshold = max(0.5, self.ruleThreshold - self.learningRate * 0.5)
            }
        }
    }

    /// 獲取當前融合參數（用於觀測）
    func getFusionParams() -> (ruleThreshold: Double, ruleWeight: Double, classifierWeight: Double) {
        var params: (Double, Double, Double) = (0, 0, 0)
        queue.sync { params = (self.ruleThreshold, self.ruleWeight, self.classifierWeight) }
        return params
    }
}



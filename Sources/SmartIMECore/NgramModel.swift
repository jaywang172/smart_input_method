import Foundation

/// N-gram 語言模型
/// 用於計算詞序列的機率，支援 unigram, bigram, trigram
public class NgramModel {
    
    // Unigram: 單個詞的機率 P(w)
    private var unigramCounts: [String: Int] = [:]
    private var unigramTotal: Int = 0
    
    // Bigram: 兩個詞的條件機率 P(w2|w1)
    private var bigramCounts: [String: [String: Int]] = [:]
    // KN 需要的延續計數：每個 w2 的不同前項數 N1+(·, w2)
    private var bigramContinuationCounts: [String: Int] = [:]
    // KN 分母：所有不同 bigram 類型總數 N1+(·, ·)
    private var bigramTypesTotal: Int = 0
    
    // Trigram: 三個詞的條件機率 P(w3|w1,w2)
    private var trigramCounts: [String: [String: Int]] = [:]
    
    // 絕對折扣平滑（Absolute Discounting）
    private let discount: Double = 0.75
    
    // 詞彙表大小
    private var vocabularySize: Int = 0
    
    public init() {}
    
    // MARK: - Training
    
    /// 訓練模型
    /// - Parameter corpus: 訓練語料（詞序列數組）
    public func train(corpus: [[String]]) {
        for sentence in corpus {
            trainOnSentence(sentence)
        }
        vocabularySize = unigramCounts.count
        recomputeKneserNeyStats()
    }
    
    /// 在單個句子上訓練
    private func trainOnSentence(_ words: [String]) {
        guard !words.isEmpty else { return }
        
        // 訓練 unigram
        for word in words {
            unigramCounts[word, default: 0] += 1
            unigramTotal += 1
        }
        
        // 訓練 bigram
        if words.count >= 2 {
            for i in 0..<(words.count - 1) {
                let w1 = words[i]
                let w2 = words[i + 1]
                
                if bigramCounts[w1] == nil {
                    bigramCounts[w1] = [:]
                }
                bigramCounts[w1]![w2, default: 0] += 1
            }
        }
        
        // 訓練 trigram
        if words.count >= 3 {
            for i in 0..<(words.count - 2) {
                let w1 = words[i]
                let w2 = words[i + 1]
                let w3 = words[i + 2]
                let key = "\(w1) \(w2)"
                
                if trigramCounts[key] == nil {
                    trigramCounts[key] = [:]
                }
                trigramCounts[key]![w3, default: 0] += 1
            }
        }
    }
    /// 計算 KN 統計（基於 bigramCounts）
    private func recomputeKneserNeyStats() {
        var cont: [String: Set<String>] = [:]
        var types = 0
        for (w1, foll) in bigramCounts {
            for (w2, c) in foll {
                if c > 0 {
                    cont[w2, default: []].insert(w1)
                    types += 1
                }
            }
        }
        bigramContinuationCounts = cont.mapValues { $0.count }
        bigramTypesTotal = max(types, 1)
    }
    
    // MARK: - Probability Calculation
    
    /// 計算 unigram 機率（log 域）
    public func unigramLogProbability(_ word: String) -> Double {
        let count = Double(unigramCounts[word] ?? 0)
        let total = Double(max(unigramTotal, 1))
        // 加微量避免 -inf
        let p = max((count - discount) / total, 1e-12)
        return log(p)
    }
    
    /// 計算 bigram 機率（log 域，Kneser-Ney 平滑）
    /// P_KN(w2|w1) = max(c(w1,w2)-D,0)/c(w1) + λ(w1) * P_cont(w2)
    /// P_cont(w2) = N1+(·,w2) / N1+(·,·)
    public func bigramLogProbability(_ word1: String, _ word2: String) -> Double {
        guard let foll = bigramCounts[word1] else {
            // 無前項資訊時，退回到 continuation 機率
            let cont = Double(bigramContinuationCounts[word2] ?? 0)
            let pCont = max(cont / Double(bigramTypesTotal), 1e-12)
            return log(pCont)
        }
        let c12 = Double(foll[word2] ?? 0)
        let c1 = Double(foll.values.reduce(0, +))
        if c1 <= 0 {
            let cont = Double(bigramContinuationCounts[word2] ?? 0)
            let pCont = max(cont / Double(bigramTypesTotal), 1e-12)
            return log(pCont)
        }
        let uniqueFollowers = Double(foll.keys.count)
        let base = max((c12 - discount) / c1, 0.0)
        let lambda = discount * uniqueFollowers / c1
        let cont = Double(bigramContinuationCounts[word2] ?? 0)
        let pCont = max(cont / Double(bigramTypesTotal), 1e-12)
        let p = max(base + lambda * pCont, 1e-12)
        return log(p)
    }
    
    /// 計算 trigram 機率（log 域，絕對折扣平滑 + 回退到 bigram）
    public func trigramLogProbability(_ word1: String, _ word2: String, _ word3: String) -> Double {
        let key = "\(word1) \(word2)"
        guard let trigrams = trigramCounts[key] else {
            return bigramLogProbability(word2, word3)
        }
        let c123 = Double(trigrams[word3] ?? 0)
        let c12 = Double(trigrams.values.reduce(0, +))
        let uniqueFollowers = Double(trigrams.keys.count)
        if c12 <= 0 { return bigramLogProbability(word2, word3) }
        let lambda = discount * uniqueFollowers / c12
        let base = max((c123 - discount) / c12, 0.0)
        let backoff = lambda * exp(bigramLogProbability(word2, word3))
        let p = max(base + backoff, 1e-12)
        return log(p)
    }
    
    /// 計算句子 log 機率（使用 bigram 回退）
    public func sentenceLogProbability(_ words: [String]) -> Double {
        guard !words.isEmpty else { return -Double.infinity }
        var logProb: Double = unigramLogProbability(words[0])
        for i in 1..<words.count {
            logProb += bigramLogProbability(words[i-1], words[i])
        }
        return logProb
    }
    
    // MARK: - Prediction
    
    /// 預測下一個最可能的詞
    /// - Parameters:
    ///   - context: 上下文詞（最多兩個）
    ///   - candidates: 候選詞列表
    /// - Returns: 排序後的候選詞及其機率
    public func predictNext(context: [String], candidates: [String]) -> [(word: String, probability: Double)] {
        var results: [(String, Double)] = []
        results.reserveCapacity(candidates.count)
        for candidate in candidates {
            let logP: Double
            if context.count >= 2 {
                logP = trigramLogProbability(context[context.count-2], context[context.count-1], candidate)
            } else if context.count == 1 {
                logP = bigramLogProbability(context[0], candidate)
            } else {
                logP = unigramLogProbability(candidate)
            }
            results.append((candidate, logP))
        }
        // 仍對外輸出可比較分數：以 logP 排序，回傳時轉為 exp 做相對值（非歸一化）
        results.sort { $0.1 > $1.1 }
        return results.map { ($0.0, exp($0.1)) }
    }
    
    /// 獲取最常見的 N 個詞
    public func topWords(n: Int) -> [(word: String, count: Int)] {
        let sorted = unigramCounts.sorted { $0.value > $1.value }
        return Array(sorted.prefix(n)).map { ($0.key, $0.value) }
    }
    
    // MARK: - Linear-Domain Convenience API

    /// 計算 unigram 機率（線性域）
    public func unigramProbability(_ word: String) -> Double {
        return exp(unigramLogProbability(word))
    }

    /// 計算 bigram 機率（線性域）
    public func bigramProbability(_ word1: String, _ word2: String) -> Double {
        return exp(bigramLogProbability(word1, word2))
    }

    /// 計算句子機率（線性域）
    public func sentenceProbability(_ words: [String]) -> Double {
        return exp(sentenceLogProbability(words))
    }

    // MARK: - Persistence
    
    /// 保存模型到檔案
    func save(to path: String) throws {
        let data: [String: Any] = [
            "unigram": unigramCounts,
            "bigram": bigramCounts,
            "trigram": trigramCounts,
            "unigramTotal": unigramTotal,
            "vocabularySize": vocabularySize
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        try jsonData.write(to: URL(fileURLWithPath: path))
    }
    
    /// 從檔案加載模型
    func load(from path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NgramModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid model file"])
        }
        
        if let unigram = json["unigram"] as? [String: Int] {
            unigramCounts = unigram
        }
        
        if let bigram = json["bigram"] as? [String: [String: Int]] {
            bigramCounts = bigram
        }
        
        if let trigram = json["trigram"] as? [String: [String: Int]] {
            trigramCounts = trigram
        }
        
        unigramTotal = json["unigramTotal"] as? Int ?? 0
        vocabularySize = json["vocabularySize"] as? Int ?? 0
    }
}

import Foundation

/// 注音符號到中文的轉換器
/// 使用 Viterbi 演算法找出最佳轉換路徑
class BopomofoConverter {
    
    // 注音到中文的映射字典
    private var bopomofoDict: [String: [String]] = [:]
    
    // N-gram 語言模型用於上下文預測
    private let ngramModel: NgramModel
    
    // Trie 用於快速查找
    private let trie: Trie
    
    init(ngramModel: NgramModel, trie: Trie) {
        self.ngramModel = ngramModel
        self.trie = trie
        loadBopomofoMappings()
    }
    
    /// 載入注音符號映射表
    private func loadBopomofoMappings() {
        // 這裡是一些常見的注音到中文映射範例
        // 實際應用中應該從完整的詞典檔案加載
        bopomofoDict = [
            "ㄋㄧˇㄏㄠˇ": ["你好", "泥好"],
            "ㄋㄧˇ": ["你", "泥", "擬"],
            "ㄏㄠˇ": ["好", "號"],
            "ㄨㄛˇ": ["我", "握"],
            "ㄕˋ": ["是", "事", "室", "世", "士"],
            "ㄓㄨㄥ": ["中", "終", "鐘", "忠"],
            "ㄨㄣˊ": ["文", "聞", "紋"],
            "ㄊㄧㄢ": ["天", "添"],
            "ㄑㄧˋ": ["氣", "器", "汽"],
            "ㄏㄣˇ": ["很", "狠"],
            "ㄇㄥˊ": ["萌", "盟", "檬"],
        ]
    }

    /// 以資料陣列載入（供 ResourceManager 使用）
    func loadMappings(_ pairs: [(chinese: String, bopomofo: String)]) {
        for (ch, bp) in pairs {
            addMapping(bopomofo: bp, chinese: ch)
        }
    }
    
    /// 將注音轉換為中文候選詞
    /// - Parameter bopomofo: 注音字串
    /// - Returns: 候選中文詞及其分數
    func convert(_ bopomofo: String) -> [(word: String, score: Double)] {
        // 嘗試直接查找完整的注音
        if let candidates = bopomofoDict[bopomofo] {
            return candidates.map { word in
                let logp = ngramModel.unigramLogProbability(word)
                return (word, exp(logp))
            }.sorted { $0.score > $1.score }
        }
        
        // 如果找不到，嘗試 beam 轉換
        return beamConvert(bopomofo, context: [])
    }
    
    /// 帶上下文的注音轉換
    /// - Parameters:
    ///   - bopomofo: 注音字串
    ///   - context: 前面的上下文詞
    /// - Returns: 候選中文詞及其分數
    func convertWithContext(_ bopomofo: String, context: [String]) -> [(word: String, score: Double)] {
        guard let candidates = bopomofoDict[bopomofo] else {
            return beamConvert(bopomofo, context: context)
        }
        
        // 使用 N-gram 模型計算上下文機率
        let results = ngramModel.predictNext(context: context, candidates: candidates)
        
        return results.map { (word: $0.word, score: $0.probability) }
    }
    
    /// 分段並轉換注音（動態規劃）
    private func segmentAndConvert(_ bopomofo: String) -> [(word: String, score: Double)] {
        let length = bopomofo.count
        guard length > 0 else { return [] }
        
        // dp[i] 表示前 i 個字符的最佳轉換結果
        var dp: [[ConversionNode]] = Array(repeating: [], count: length + 1)
        dp[0] = [ConversionNode(word: "", score: 1.0, path: [])]
        
        let chars = Array(bopomofo)
        
        for i in 1...length {
            for j in 0..<i {
                let segment = String(chars[j..<i])
                
                if let candidates = bopomofoDict[segment] {
                    for candidate in candidates {
                        let logp = ngramModel.unigramLogProbability(candidate)
                        for prevNode in dp[j] {
                            let newScore = prevNode.score * exp(logp)
                            let newPath = prevNode.path + [candidate]
                            let newNode = ConversionNode(word: candidate, score: newScore, path: newPath)
                            dp[i].append(newNode)
                        }
                    }
                }
            }
            
            // 保留分數最高的前 10 個節點（剪枝）
            dp[i].sort { $0.score > $1.score }
            if dp[i].count > 10 {
                dp[i] = Array(dp[i].prefix(10))
            }
        }
        
        // 返回最終結果
        return dp[length].map { node in
            let fullWord = node.path.joined()
            return (word: fullWord, score: node.score)
        }
    }
    
    /// 使用 Viterbi 演算法找出最佳轉換路徑
    func viterbiConvert(_ bopomofoSequence: [String]) -> [String] {
        guard !bopomofoSequence.isEmpty else { return [] }
        
        // 狀態：每個位置可能的中文字
        var states: [[State]] = []
        
        // 初始化第一個字的狀態
        if let firstCandidates = bopomofoDict[bopomofoSequence[0]] {
            states.append(firstCandidates.map { candidate in
                let logp = ngramModel.unigramLogProbability(candidate)
                return State(word: candidate, probability: exp(logp), backpointer: nil)
            })
        } else {
            return []
        }
        
        // 動態規劃計算後續狀態
        for i in 1..<bopomofoSequence.count {
            guard let candidates = bopomofoDict[bopomofoSequence[i]] else {
                continue
            }
            
            var currentStates: [State] = []
            
            for candidate in candidates {
                var maxProb = 0.0
                var bestPrev: State?
                
                // 找出前一個狀態中轉移到當前狀態機率最大的
                for prevState in states[i-1] {
                    let transLogProb = ngramModel.bigramLogProbability(prevState.word, candidate)
                    let totalProb = prevState.probability * exp(transLogProb)
                    
                    if totalProb > maxProb {
                        maxProb = totalProb
                        bestPrev = prevState
                    }
                }
                
                if let best = bestPrev {
                    currentStates.append(State(word: candidate, probability: maxProb, backpointer: best))
                }
            }
            
            states.append(currentStates)
        }
        
        // 回溯找出最佳路徑
        guard let lastStates = states.last,
              let bestFinal = lastStates.max(by: { $0.probability < $1.probability }) else {
            return []
        }
        
        var result: [String] = []
        var current: State? = bestFinal
        
        while let state = current {
            result.insert(state.word, at: 0)
            current = state.backpointer
        }
        
        return result
    }

    /// Beam search（log 域），在未知映射或長序列時更穩定
    private func beamConvert(_ bopomofo: String, context: [String], beamWidth: Int = 8) -> [(word: String, score: Double)] {
        let chars = Array(bopomofo)
        let n = chars.count
        guard n > 0 else { return [] }
        struct BeamState { let idx: Int; let logp: Double; let path: [String] }
        var beams: [BeamState] = [BeamState(idx: 0, logp: 0.0, path: [])]
        for i in 0..<n {
            var next: [BeamState] = []
            for b in beams {
                if b.idx != i { continue }
                // 嘗試擴展不同長度的片段
                for j in (i+1)...n {
                    let seg = String(chars[i..<j])
                    guard let words = bopomofoDict[seg] else { continue }
                    for w in words {
                        let lp: Double
                        if let last = b.path.last {
                            lp = b.logp + ngramModel.bigramLogProbability(last, w)
                        } else if context.last != nil {
                            lp = b.logp + ngramModel.bigramLogProbability(context.last!, w)
                        } else {
                            lp = b.logp + ngramModel.unigramLogProbability(w)
                        }
                        next.append(BeamState(idx: j, logp: lp, path: b.path + [w]))
                    }
                }
            }
            next.sort { $0.logp > $1.logp }
            if next.count > beamWidth { next = Array(next.prefix(beamWidth)) }
            beams = next
        }
        // 回收完成到末尾的序列
        let finals = beams.filter { $0.idx == n }
        let results = finals.map { (word: $0.path.joined(), score: exp($0.logp)) }
        return results.sorted { $0.score > $1.score }
    }
    
    /// 添加自定義注音映射
    func addMapping(bopomofo: String, chinese: String) {
        if bopomofoDict[bopomofo] != nil {
            if !bopomofoDict[bopomofo]!.contains(chinese) {
                bopomofoDict[bopomofo]!.append(chinese)
            }
        } else {
            bopomofoDict[bopomofo] = [chinese]
        }
    }
    
    /// 從檔案加載注音詞典
    func loadDictionary(from path: String) throws {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            
            let chinese = parts[0]
            let bopomofo = parts[1]
            addMapping(bopomofo: bopomofo, chinese: chinese)
        }
    }
}

// MARK: - Helper Structures

private struct ConversionNode {
    let word: String
    let score: Double
    let path: [String]
}

private class State {
    let word: String
    let probability: Double
    let backpointer: State?
    
    init(word: String, probability: Double, backpointer: State?) {
        self.word = word
        self.probability = probability
        self.backpointer = backpointer
    }
}

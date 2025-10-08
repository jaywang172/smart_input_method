import Foundation

/// 候選融合：去重、來源權重、分數正規化與截斷
struct CandidateFusion {
    struct Item {
        let text: String
        let score: Double
        let source: InputEngine.Candidate.CandidateSource
    }

    /// 融合多來源候選
    /// - Parameters:
    ///   - items: 候選清單
    ///   - sourceWeights: 來源權重（可選）
    ///   - limit: 回傳上限
    static func fuse(_ items: [Item], sourceWeights: [InputEngine.Candidate.CandidateSource: Double] = [:], limit: Int) -> [Item] {
        if items.isEmpty { return [] }
        var best: [String: Item] = [:]
        for it in items {
            let w = sourceWeights[it.source] ?? 1.0
            let s = it.score * w
            if let existed = best[it.text] {
                if s > existed.score {
                    best[it.text] = Item(text: it.text, score: s, source: it.source)
                }
            } else {
                best[it.text] = Item(text: it.text, score: s, source: it.source)
            }
        }
        var merged = Array(best.values)
        // 分數正規化（min-max）
        if let maxS = merged.map({ $0.score }).max(), let minS = merged.map({ $0.score }).min(), maxS > minS {
            merged = merged.map { it in
                let norm = (it.score - minS) / (maxS - minS)
                return Item(text: it.text, score: norm, source: it.source)
            }
        }
        merged.sort { $0.score > $1.score }
        if merged.count > limit { merged = Array(merged.prefix(limit)) }
        return merged
    }
}



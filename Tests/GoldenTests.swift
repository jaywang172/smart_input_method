import Foundation

/// 黃金測試：固定輸入 -> 穩定候選排序（top-K Jaccard 檢查）
class GoldenTests {
    struct Case {
        let name: String
        let inputs: [String]
        let expectedTop: [String]
        let k: Int
    }

    private func jaccard(_ a: [String], _ b: [String]) -> Double {
        let sa = Set(a)
        let sb = Set(b)
        let inter = sa.intersection(sb).count
        let uni = sa.union(sb).count
        if uni == 0 { return 1.0 }
        return Double(inter) / Double(uni)
    }

    func run() {
        print("\n==== 黃金測試 ====")
        let engine = InputEngine(config: InputEngineConfig(lazyLoadResources: true))

        let cases: [Case] = [
            Case(name: "bpmf_nihao", inputs: ["ㄋ", "ㄧ", "ˇ", "ㄏ", "ㄠ", "ˇ"], expectedTop: ["你好"], k: 3),
            Case(name: "english_hel", inputs: ["h","e","l"], expectedTop: ["hello"], k: 3),
        ]

        for c in cases {
            engine.reset()
            var last: [InputEngine.Candidate] = []
            for ch in c.inputs { last = engine.handleInput(ch) }
            let tops = Array(last.prefix(c.k)).map { $0.text }
            let score = jaccard(tops, c.expectedTop)
            print("[\(c.name)] top\(c.k) = \(tops), jaccard vs expected = \(String(format: "%.2f", score))")
            assert(score >= 0.5, "黃金測試 \(c.name) 相似度過低")
        }

        print("黃金測試通過 ✅\n")
    }
}

GoldenTests().run()



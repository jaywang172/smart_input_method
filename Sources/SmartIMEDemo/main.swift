import Foundation
import SmartIMECore

func main() {
    print("🚀 智能輸入法演示")
    print("==================")

    // 測試基本組件
    print("1. 測試 Trie...")
    let trie = RadixTrie()
    trie.insert("hello", frequency: 1)
    let result = trie.search("hello")
    print("Trie 搜索結果: \(result)")

    print("2. 測試 LanguageDetector...")
    let detector = LanguageDetector()
    let lang = detector.detect("hello")
    print("語言檢測結果: \(lang)")

    print("3. 測試 NgramModel...")
    let ngram = NgramModel()
    let corpus = [["hello", "world"], ["hello", "swift"]]
    ngram.train(corpus: corpus)
    let prob = exp(ngram.unigramLogProbability("hello"))
    print("N-gram 機率: \(prob)")

    // 測試 InputEngine（擴充版詞典）
    print("\n4. 測試 InputEngine 擴充詞典...")
    let engine = InputEngine()

    // 中文候選
    let zhCandidates = engine.handleInput("你好")
    print("中文「你好」候選: \(zhCandidates.map { $0.text })")

    // 英文補全
    engine.clearInput()
    let enCandidates = engine.handleInput("hel")
    print("英文「hel」候選: \(enCandidates.map { $0.text })")

    // 注音轉換
    engine.clearInput()
    let bpmfCandidates = engine.handleInput("ㄋㄧˇㄏㄠˇ")
    print("注音候選: \(bpmfCandidates.map { $0.text })")

    // 測試 IMEDemo
    print("\n5. 運行 IMEDemo...")
    let demo = IMEDemo()
    demo.runInteractiveDemo()
    demo.testDataStructurePerformance()

    print("\n6. 進行密集基準測試 (Stress Test)...")
    let testWords = ["hello", "world", "swift", "su3cl3", "rup wu0", "你好", "測試", "123"]
    let testCount = 10000
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<testCount {
        let word = testWords.randomElement()!
        _ = engine.handleInput(word)
        engine.clearInput()
    }
    let duration = (CFAbsoluteTimeGetCurrent() - start)
    let avgLatency = (duration / Double(testCount)) * 1000 // in ms
    let qps = Double(testCount) / duration
    print("測試次數: \(testCount)")
    print("總耗時: \(String(format: "%.4f", duration)) 秒")
    print("平均生成延遲: \(String(format: "%.4f", avgLatency)) ms")
    print("吞吐量 (QPS): \(String(format: "%.1f", qps)) 查詢/秒")

    print("✅ 演示完成！")
}

main()

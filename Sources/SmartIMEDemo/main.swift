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

    print("✅ 演示完成！")
}

main()

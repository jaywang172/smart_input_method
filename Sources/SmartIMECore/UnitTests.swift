import Foundation

/// 單元測試 - Trie 資料結構
class TrieTests {
    
    func testInsertAndSearch() {
        print("測試: 插入和搜尋")
        let trie = Trie()
        
        trie.insert("apple", frequency: 10)
        trie.insert("app", frequency: 5)
        trie.insert("application", frequency: 8)
        
        assert(trie.search("apple"), "應該找到 apple")
        assert(trie.search("app"), "應該找到 app")
        assert(!trie.search("appl"), "不應該找到 appl")
        assert(!trie.search("banana"), "不應該找到 banana")
        
        print("✅ 通過\n")
    }
    
    func testPrefixSearch() {
        print("測試: 前綴搜尋")
        let trie = Trie()
        
        trie.insert("cat", frequency: 10)
        trie.insert("car", frequency: 8)
        trie.insert("card", frequency: 6)
        trie.insert("care", frequency: 7)
        trie.insert("careful", frequency: 5)
        
        assert(trie.startsWith("ca"), "應該有 ca 前綴")
        assert(trie.startsWith("car"), "應該有 car 前綴")
        assert(!trie.startsWith("dog"), "不應該有 dog 前綴")
        
        print("✅ 通過\n")
    }
    
    func testGetAllWordsWithPrefix() {
        print("測試: 獲取所有前綴匹配的詞")
        let trie = Trie()
        
        trie.insert("hello", frequency: 100)
        trie.insert("help", frequency: 90)
        trie.insert("hero", frequency: 80)
        trie.insert("world", frequency: 70)
        
        let results = trie.getAllWordsWithPrefix("he", limit: 10)
        
        assert(results.count == 3, "應該有3個以 he 開頭的詞")
        assert(results[0].word == "hello", "第一個應該是 hello (頻率最高)")
        
        print("結果: \(results)")
        print("✅ 通過\n")
    }
    
    func testBatchInsert() {
        print("測試: 批量插入")
        let trie = Trie()
        
        let words = [
            ("swift", 100),
            ("python", 90),
            ("java", 80),
            ("javascript", 85),
        ]
        
        trie.insertBatch(words)
        
        assert(trie.count == 4, "應該有4個詞")
        assert(trie.search("swift"), "應該找到 swift")
        assert(trie.search("javascript"), "應該找到 javascript")
        
        print("✅ 通過\n")
    }
    
    func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("Trie 資料結構測試")
        print(String(repeating: "=", count: 60) + "\n")
        
        testInsertAndSearch()
        testPrefixSearch()
        testGetAllWordsWithPrefix()
        testBatchInsert()
        
        print("所有 Trie 測試通過！✅")
    }
}

/// 單元測試 - N-gram 模型
class NgramModelTests {
    
    func testUnigramProbability() {
        print("測試: Unigram 機率")
        let model = NgramModel()
        
        let corpus = [
            ["我", "愛", "你"],
            ["你", "愛", "我"],
            ["我", "愛", "吃飯"],
        ]
        
        model.train(corpus: corpus)
        
        let probI = exp(model.unigramLogProbability("我"))
        let probLove = exp(model.unigramLogProbability("愛"))
        
        print("P(我) = \(probI)")
        print("P(愛) = \(probLove)")
        
        assert(probI > 0, "機率應該大於0")
        assert(probLove > 0, "機率應該大於0")
        
        print("✅ 通過\n")
    }
    
    func testBigramProbability() {
        print("測試: Bigram 機率")
        let model = NgramModel()
        
        let corpus = [
            ["今天", "天氣", "很好"],
            ["今天", "天氣", "不好"],
            ["今天", "很", "開心"],
        ]
        
        model.train(corpus: corpus)
        
        let prob1 = exp(model.bigramLogProbability("今天", "天氣"))
        let prob2 = exp(model.bigramLogProbability("天氣", "很好"))
        
        print("P(天氣|今天) = \(prob1)")
        print("P(很好|天氣) = \(prob2)")
        
        assert(prob1 > 0, "機率應該大於0")
        
        print("✅ 通過\n")
    }
    
    func testPredictNext() {
        print("測試: 預測下一個詞")
        let model = NgramModel()
        
        let corpus = [
            ["我", "喜歡", "編程"],
            ["我", "喜歡", "音樂"],
            ["我", "不喜歡", "下雨"],
        ]
        
        model.train(corpus: corpus)
        
        let candidates = ["編程", "音樂", "下雨"]
        let predictions = model.predictNext(context: ["我", "喜歡"], candidates: candidates)
        
        print("預測結果:")
        for (word, prob) in predictions {
            print("  \(word): \(String(format: "%.4f", prob))")
        }
        
        assert(!predictions.isEmpty, "應該有預測結果")
        
        print("✅ 通過\n")
    }
    
    func testSentenceProbability() {
        print("測試: 句子機率")
        let model = NgramModel()
        
        let corpus = [
            ["我", "愛", "你"],
            ["我", "愛", "你"],
            ["你", "愛", "我"],
        ]
        
        model.train(corpus: corpus)
        
        let prob1 = exp(model.sentenceLogProbability(["我", "愛", "你"]))
        let prob2 = exp(model.sentenceLogProbability(["你", "愛", "我"]))
        
        print("P(我 愛 你) = \(prob1)")
        print("P(你 愛 我) = \(prob2)")
        
        assert(prob1 > prob2, "「我愛你」應該比「你愛我」機率高")
        
        print("✅ 通過\n")
    }
    
    func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("N-gram 模型測試")
        print(String(repeating: "=", count: 60) + "\n")
        
        testUnigramProbability()
        testBigramProbability()
        testPredictNext()
        testSentenceProbability()
        
        print("所有 N-gram 測試通過！✅")
    }
}

/// 單元測試 - 語言檢測器
class LanguageDetectorTests {
    
    func testDetectChinese() {
        print("測試: 檢測中文")
        let detector = LanguageDetector()
        
        let testCases = ["你好", "中文輸入法", "我愛編程"]
        
        for testCase in testCases {
            let result = detector.detect(testCase)
            print("\(testCase) -> \(result.language) (信心度: \(String(format: "%.2f", result.confidence)))")
            assert(result.language == .chinese || result.language == .mixed, "應該檢測為中文")
        }
        
        print("✅ 通過\n")
    }
    
    func testDetectEnglish() {
        print("測試: 檢測英文")
        let detector = LanguageDetector()
        
        let testCases = ["hello", "world", "programming"]
        
        for testCase in testCases {
            let result = detector.detect(testCase)
            print("\(testCase) -> \(result.language) (信心度: \(String(format: "%.2f", result.confidence)))")
            assert(result.language == .english || result.language == .mixed, "應該檢測為英文")
        }
        
        print("✅ 通過\n")
    }
    
    func testDetectBopomofo() {
        print("測試: 檢測注音")
        let detector = LanguageDetector()
        
        let testCases = ["ㄋㄧˇㄏㄠˇ", "ㄨㄛˇ", "ㄏㄣˇㄏㄠˇ"]
        
        for testCase in testCases {
            let result = detector.detect(testCase)
            print("\(testCase) -> \(result.language) (信心度: \(String(format: "%.2f", result.confidence)))")
            assert(result.language == .chinese, "注音應該檢測為中文")
        }
        
        print("✅ 通過\n")
    }
    
    func testDetectWithContext() {
        print("測試: 帶上下文的檢測")
        let detector = LanguageDetector()
        
        // 中文上下文
        let result1 = detector.detect("test", context: "我在學習")
        print("'test' 在中文上下文 -> \(result1.language)")
        
        // 英文上下文
        let result2 = detector.detect("測試", context: "hello world")
        print("'測試' 在英文上下文 -> \(result2.language)")
        
        print("✅ 通過\n")
    }
    
    func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("語言檢測器測試")
        print(String(repeating: "=", count: 60) + "\n")
        
        testDetectChinese()
        testDetectEnglish()
        testDetectBopomofo()
        testDetectWithContext()
        
        print("所有語言檢測測試通過！✅")
    }
}

// MARK: - Test Runner

func runAllTests() {
    print("\n" + "🧪 開始運行單元測試" + "\n")
    
    let trieTests = TrieTests()
    trieTests.runAllTests()
    
    let ngramTests = NgramModelTests()
    ngramTests.runAllTests()
    
    let detectorTests = LanguageDetectorTests()
    detectorTests.runAllTests()
    
    print("\n" + String(repeating: "=", count: 60))
    print("🎉 所有測試通過！")
    print(String(repeating: "=", count: 60) + "\n")
}

// 測試執行器（由外部調用）

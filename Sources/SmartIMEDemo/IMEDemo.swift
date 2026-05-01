import Foundation
import SmartIMECore

/// 測試程式 - 展示輸入法引擎的使用
class IMEDemo {
    
    private let engine: InputEngine
    
    init() {
        print("🚀 初始化智能輸入法引擎...")
        engine = InputEngine()
        print("✅ 初始化完成！\n")
    }
    
    /// 運行互動式示範
    func runInteractiveDemo() {
        print(String(repeating: "=", count: 60))
        print("智能混合輸入法示範")
        print(String(repeating: "=", count: 60))
        print()
        
        // 示範1: 注音轉中文
        demonstrateBopomofoConversion()
        
        // 示範2: 英文自動補全
        demonstrateEnglishCompletion()
        
        // 示範3: 語言檢測
        demonstrateLanguageDetection()
        
        // 示範4: 上下文預測
        demonstrateContextPrediction()
        
        // 示範5: 混合輸入
        demonstrateMixedInput()
        
        print("\n" + String(repeating: "=", count: 60))
        print("示範結束")
        print(String(repeating: "=", count: 60))
    }
    
    // MARK: - Demonstrations
    
    private func demonstrateBopomofoConversion() {
        printSection("1. 注音轉中文")
        
        let testInputs = ["ㄋㄧˇㄏㄠˇ", "ㄨㄛˇ", "ㄏㄣˇ"]
        
        for input in testInputs {
            print("輸入: \(input)")
            let candidates = engine.handleInput(input)
            
            if !candidates.isEmpty {
                print("候選詞:")
                for (index, candidate) in candidates.prefix(5).enumerated() {
                    print("  \(index + 1). \(candidate.text) (分數: \(String(format: "%.3f", candidate.score)))")
                }
            } else {
                print("  (無候選詞)")
            }
            
            engine.clearInput()
            print()
        }
    }
    
    private func demonstrateEnglishCompletion() {
        printSection("2. 英文自動補全")
        
        let testInputs = ["hel", "swi", "prog"]
        
        for input in testInputs {
            print("輸入: \(input)")
            let candidates = engine.handleInput(input)
            
            if !candidates.isEmpty {
                print("候選詞:")
                for (index, candidate) in candidates.prefix(5).enumerated() {
                    print("  \(index + 1). \(candidate.text) (分數: \(String(format: "%.3f", candidate.score)))")
                }
            } else {
                print("  (無候選詞)")
            }
            
            engine.clearInput()
            print()
        }
    }
    
    private func demonstrateLanguageDetection() {
        printSection("3. 語言自動檢測")
        
        let detector = LanguageDetector()
        let testInputs = [
            "ㄋㄧˇㄏㄠˇ",
            "hello",
            "你好世界",
            "swift programming",
            "123abc"
        ]
        
        for input in testInputs {
            let result = detector.detect(input)
            print("輸入: \(input)")
            print("  檢測結果: \(result.language)")
            print("  信心度: \(String(format: "%.2f", result.confidence))")
            print()
        }
    }
    
    private func demonstrateContextPrediction() {
        printSection("4. 上下文預測")
        
        // 模擬一個輸入序列
        let sequence = ["今天", "天氣"]
        
        print("已輸入的上下文: \(sequence.joined(separator: " "))")
        
        // 選擇一些詞來建立上下文
        for word in sequence {
            let candidates = engine.handleInput(word)
            if candidates.first != nil {
                engine.selectCandidate(at: 0)
            } else {
                engine.clearInput()
            }
        }
        
        print("基於上下文的建議:")
        let suggestions = engine.getSuggestions(limit: 5)
        for (index, suggestion) in suggestions.enumerated() {
            print("  \(index + 1). \(suggestion)")
        }
        
        engine.reset()
        print()
    }
    
    private func demonstrateMixedInput() {
        printSection("5. 混合中英文輸入")
        
        print("這個示範展示系統如何處理混合輸入")
        print("(實際使用時，系統會根據上下文自動判斷語言)\n")
        
        // 測試場景
        let scenarios = [
            ("學習", "學習中文"),
            ("swift", "然後切換到英文"),
            ("ㄊㄧㄢ", "再輸入注音"),
        ]
        
        for (input, description) in scenarios {
            print("場景: \(description)")
            print("輸入: \(input)")
            
            let candidates = engine.handleInput(input)
            
            if !candidates.isEmpty {
                print("候選詞:")
                for (index, candidate) in candidates.prefix(3).enumerated() {
                    let source = candidateSourceDescription(candidate.source)
                    print("  \(index + 1). \(candidate.text) [\(source)]")
                }
            }
            
            engine.clearInput()
            print()
        }
    }
    
    // MARK: - Helper Methods
    
    private func printSection(_ title: String) {
        print("\n" + String(repeating: "-", count: 60))
        print(title)
        print(String(repeating: "-", count: 60) + "\n")
    }
    
    private func candidateSourceDescription(_ source: InputEngine.Candidate.CandidateSource) -> String {
        switch source {
        case .bopomofoConversion:
            return "注音轉換"
        case .englishCompletion:
            return "英文補全"
        case .contextPrediction:
            return "上下文預測"
        }
    }
    
    /// 測試資料結構性能
    func testDataStructurePerformance() {
        printSection("資料結構性能測試")
        
        // 測試 Trie
        print("測試 Trie 插入和查找性能...")
        let trie = Trie()
        let words = (1...10000).map { "word\($0)" }
        
        let startInsert = Date()
        for word in words {
            trie.insert(word, frequency: Int.random(in: 1...100))
        }
        let insertTime = Date().timeIntervalSince(startInsert)
        print("插入 10,000 個詞耗時: \(String(format: "%.4f", insertTime)) 秒")
        
        let startSearch = Date()
        for word in words.prefix(1000) {
            _ = trie.search(word)
        }
        let searchTime = Date().timeIntervalSince(startSearch)
        print("查找 1,000 個詞耗時: \(String(format: "%.4f", searchTime)) 秒")
        
        print("平均查找時間: \(String(format: "%.6f", searchTime / 1000)) 秒/詞")
        print()
    }
    
}

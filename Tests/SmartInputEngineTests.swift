#!/usr/bin/env swift

import Foundation

// 導入核心模塊（需要編譯時包含）
// 這個測試文件用於驗證 SmartInputEngine 的功能

/// 簡單的測試框架
class TestRunner {
    var passedTests = 0
    var failedTests = 0
    
    func assert(_ condition: Bool, _ message: String) {
        if condition {
            print("✅ PASS: \(message)")
            passedTests += 1
        } else {
            print("❌ FAIL: \(message)")
            failedTests += 1
        }
    }
    
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual == expected {
            print("✅ PASS: \(message)")
            passedTests += 1
        } else {
            print("❌ FAIL: \(message)")
            print("   Expected: \(expected)")
            print("   Actual: \(actual)")
            failedTests += 1
        }
    }
    
    func printSummary() {
        print("\n" + String(repeating: "=", count: 50))
        print("測試總結")
        print(String(repeating: "=", count: 50))
        print("✅ 通過: \(passedTests)")
        print("❌ 失敗: \(failedTests)")
        print("總計: \(passedTests + failedTests)")
        print("成功率: \(passedTests * 100 / (passedTests + failedTests))%")
    }
}

/// 測試用例
func runTests() {
    print("🧪 開始測試 SmartInputEngine")
    print(String(repeating: "=", count: 50))
    
    let runner = TestRunner()
    
    // 測試 KeyboardMapper
    print("\n📝 測試 KeyboardMapper")
    print(String(repeating: "-", count: 50))
    
    // 這裡需要實際導入 KeyboardMapper 類
    // 由於是獨立的測試腳本，我們先列出測試用例
    
    let testCases = [
        // (輸入, 預期注音, 預期輸出, 描述)
        ("su3cl3", "ㄋㄧˇㄏㄠˇ", "你好", "注音輸入：你好"),
        ("hello", "ㄘㄍㄠㄠㄟ", "hello", "英文輸入：hello"),
        ("j3", "ㄨˇ", "我", "注音輸入：我"),
        ("rup", "ㄐㄧㄣ", "今", "注音輸入：今"),
        ("wu0", "ㄊㄧㄢ", "天", "注音輸入：天"),
        ("cl3", "ㄏㄠˇ", "好", "注音輸入：好"),
        ("programming", "ㄣㄐㄟㄕㄐㄇㄩㄩㄛㄙㄕ", "programming", "英文輸入：programming"),
        ("test", "ㄔㄍㄋㄔ", "test", "英文輸入：test")
    ]
    
    print("\n預期測試用例：")
    for (input, bopomofo, output, description) in testCases {
        print("  • \(description)")
        print("    輸入: \(input)")
        print("    預期注音: \(bopomofo)")
        print("    預期輸出: \(output)")
    }
    
    // 測試 DictionaryLookup
    print("\n📝 測試 DictionaryLookup")
    print(String(repeating: "-", count: 50))
    
    let dictionaryTests = [
        ("ㄋㄧˇㄏㄠˇ", true, "你好", "直接查找：你好"),
        ("ㄘㄍㄠㄠㄟ", false, nil, "無效注音：hello"),
        ("ㄐㄧㄣ ㄊㄧㄢ", true, "今 天", "空格分詞：今天"),
        ("ㄋㄧˇㄏㄠˇㄨㄛˇ", true, "你好 我", "動態分詞：你好我")
    ]
    
    print("\n預期字典測試：")
    for (bopomofo, shouldFind, expected, description) in dictionaryTests {
        print("  • \(description)")
        print("    注音: \(bopomofo)")
        print("    應該找到: \(shouldFind)")
        if let exp = expected {
            print("    預期結果: \(exp)")
        }
    }
    
    // 測試 SmartInputEngine
    print("\n📝 測試 SmartInputEngine")
    print(String(repeating: "-", count: 50))
    
    print("\n預期智能檢測：")
    print("  1. su3cl3 → 檢測為注音 → 輸出：你好")
    print("  2. hello → 檢測為英文 → 輸出：hello")
    print("  3. j3 → 檢測為注音 → 輸出：我")
    print("  4. rup wu0 wu0 fu45p cl3 → 檢測為注音 → 輸出：今天天氣真好")
    
    runner.printSummary()
}

// 運行測試
runTests()

print("\n" + String(repeating: "=", count: 50))
print("💡 提示")
print(String(repeating: "=", count: 50))
print("這是測試用例定義文件。")
print("要運行實際測試，需要編譯包含核心模塊的完整項目。")
print("\n編譯命令：")
print("  cd /Users/jaywang/Desktop/輸入法")
print("  swiftc -o Tests/test_smart_engine \\")
print("    Core/KeyboardMapper.swift \\")
print("    Core/DictionaryLookup.swift \\")
print("    Core/SmartInputEngine.swift \\")
print("    Tests/SmartInputEngineTests.swift")
print("\n運行測試：")
print("  ./Tests/test_smart_engine")
print(String(repeating: "=", count: 50))

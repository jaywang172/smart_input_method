import Foundation

/// 鍵盤映射器：英文鍵盤 → 注音符號
/// 基於 truly_smart_input.swift 的驗證邏輯
class KeyboardMapper {
    
    // 英文鍵盤到注音符號的映射表
    private let mapping: [Character: String] = [
        // 聲母
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
        "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
        "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
        "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
        "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
        
        // 韻母
        "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
        "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ", "-": "ㄦ",
        
        // 聲調
        " ": " ",   // 空格（一聲）
        "6": "ˊ",   // 二聲
        "3": "ˇ",   // 三聲
        "4": "ˋ",   // 四聲
        "7": "˙"    // 輕聲
    ]
    
    /// 初始化
    init() {
        // 可以從外部 JSON 文件加載映射表（未來優化）
    }
    
    /// 轉換英文鍵盤輸入為注音序列
    /// - Parameter input: 英文鍵盤輸入（例如："su3cl3"）
    /// - Returns: 注音序列（例如："ㄋㄧˇㄏㄠˇ"）
    func convert(_ input: String) -> String {
        var result = ""
        for char in input.lowercased() {
            if let bopomofo = mapping[char] {
                result += bopomofo
            } else {
                // 保留無法映射的字符（例如：英文字母）
                result += String(char)
            }
        }
        return result
    }
    
    /// 檢查字符是否為注音符號
    /// - Parameter char: 要檢查的字符
    /// - Returns: 是否為注音符號
    func isBopomofoCharacter(_ char: Character) -> Bool {
        let bopomofoChars = "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦㄧㄨㄩˊˇˋ˙ "
        return bopomofoChars.contains(char)
    }
    
    /// 獲取映射表（用於調試）
    func getMapping() -> [Character: String] {
        return mapping
    }
}

// MARK: - 使用範例

/*
let mapper = KeyboardMapper()

// 範例 1: 你好
let input1 = "su3cl3"
let bopomofo1 = mapper.convert(input1)
print("\(input1) → \(bopomofo1)")  // su3cl3 → ㄋㄧˇㄏㄠˇ

// 範例 2: 今天天氣真好
let input2 = "rup wu0 wu0 fu45p cl3"
let bopomofo2 = mapper.convert(input2)
print("\(input2) → \(bopomofo2)")  // rup wu0 wu0 fu45p cl3 → ㄐㄧㄣ ㄊㄧㄢ ㄊㄧㄢ ㄑㄧˋㄓㄣ ㄏㄠˇ

// 範例 3: 英文輸入
let input3 = "hello"
let bopomofo3 = mapper.convert(input3)
print("\(input3) → \(bopomofo3)")  // hello → ㄘㄍㄠㄠㄟ
*/

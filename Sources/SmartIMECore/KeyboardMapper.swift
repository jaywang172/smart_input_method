import Foundation

/// 鍵盤映射器：英文鍵盤 → 注音符號
/// 基於 truly_smart_input.swift 的驗證邏輯
public class KeyboardMapper {
    
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
    public init() {}
    
    /// 轉換英文鍵盤輸入為注音序列
    /// - Parameter input: 英文鍵盤輸入（例如："su3cl3"）
    /// - Returns: 注音序列（例如："ㄋㄧˇㄏㄠˇ"）
    public func convert(_ input: String) -> String {
        var result = ""
        for char in input.lowercased() {
            if let bopomofo = mapping[char] {
                result += bopomofo
            } else {
                // 保留無法映射的字符
                result += String(char)
            }
        }
        return result
    }
    
    /// 檢查輸入是否全部可映射為注音符號（判斷是否為鍵盤注音輸入）
    /// - Parameter input: 英文鍵盤輸入
    /// - Returns: true 表示所有字元都可映射（很可能是注音輸入）
    public func isFullyMappable(_ input: String) -> Bool {
        return input.lowercased().allSatisfy { mapping[$0] != nil }
    }
    
    /// 檢查字符是否為注音符號
    public func isBopomofoCharacter(_ char: Character) -> Bool {
        let bopomofoChars = "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦㄧㄨㄩˊˇˋ˙ "
        return bopomofoChars.contains(char)
    }
    
    /// 獲取映射表（用於調試）
    public func getMapping() -> [Character: String] {
        return mapping
    }
    
    /// 聲調鍵集合
    public let toneKeys: Set<Character> = ["6", "3", "4", "7"]
    
    /// 檢查字元是否為聲調鍵
    public func isToneKey(_ char: Character) -> Bool {
        return toneKeys.contains(char)
    }
    
    /// 將鍵盤輸入切分為音節群組（依聲調鍵為切分點）
    /// - Parameter input: 原始鍵盤輸入（例如："su3cl3"）
    /// - Returns: 音節群組（例如：["su3", "cl3"]）
    public func segmentToSyllables(_ input: String) -> [String] {
        var syllables: [String] = []
        var current = ""
        
        for char in input.lowercased() {
            current.append(char)
            if toneKeys.contains(char) {
                syllables.append(current)
                current = ""
            }
        }
        
        // 最後一段（未輸入聲調的部分）
        if !current.isEmpty {
            syllables.append(current)
        }
        
        return syllables
    }
}

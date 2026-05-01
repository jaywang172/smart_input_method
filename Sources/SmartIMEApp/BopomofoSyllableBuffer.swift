import Foundation

/// 注音單音節緩衝區
///
/// 管理單一音節的輸入，使用四槽位架構：
/// `[ 聲母 ] + [ 介音 ] + [ 韻母 ] + [ 聲調 ]`
///
/// 範例：
/// ```
/// handle("s") → consumed          // ㄋ
/// handle("u") → consumed          // ㄋㄧ
/// handle("3") → syllableComplete  // ㄋㄧˇ → "你"
/// ```
public class BopomofoSyllableBuffer {

    // MARK: - 大千式鍵盤映射表

    /// 鍵 → 注音符號（聲母/介音/韻母）
    private static let keyToBopomofo: [Character: Character] = [
        // 聲母
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
        "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
        "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
        "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
        "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
        // 介音
        "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
        // 韻母
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
        "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ",
        "-": "ㄦ",
    ]

    /// 鍵 → 聲調符號
    private static let keyToTone: [Character: Character] = [
        "6": "ˊ",   // 二聲
        "3": "ˇ",   // 三聲
        "4": "ˋ",   // 四聲
        "7": "˙",   // 輕聲
        // Space 代表一聲（無符號，隱含）
    ]

    // MARK: - 分類集合

    private static let initials: Set<Character> = [
        "ㄅ","ㄆ","ㄇ","ㄈ","ㄉ","ㄊ","ㄋ","ㄌ",
        "ㄍ","ㄎ","ㄏ","ㄐ","ㄑ","ㄒ",
        "ㄓ","ㄔ","ㄕ","ㄖ","ㄗ","ㄘ","ㄙ"
    ]
    private static let medials: Set<Character> = ["ㄧ","ㄨ","ㄩ"]
    private static let finals: Set<Character> = [
        "ㄚ","ㄛ","ㄜ","ㄝ","ㄞ","ㄟ","ㄠ","ㄡ",
        "ㄢ","ㄣ","ㄤ","ㄥ","ㄦ"
    ]

    // MARK: - 槽位

    public private(set) var initial: Character? = nil   // 聲母
    public private(set) var medial: Character? = nil    // 介音
    public private(set) var final_: Character? = nil    // 韻母
    public private(set) var tone: Character? = nil      // 聲調（nil = 一聲）

    // 音節是否已完整（已觸發聲調）
    public private(set) var isComplete: Bool = false

    // MARK: - 結果型別

    public enum HandleResult {
        /// 按鍵被音節槽消耗，音節尚未完成
        case consumed
        /// 音節完成（聲調鍵已按），可查字典
        case syllableComplete
        /// 按鍵不是注音鍵，不屬於此音節
        case notBopomofo
    }

    // MARK: - 公開 API

    /// 清空音節槽
    public func clear() {
        initial = nil
        medial = nil
        final_ = nil
        tone = nil
        isComplete = false
    }

    /// 是否完全空白
    public var isEmpty: Bool {
        return initial == nil && medial == nil && final_ == nil && tone == nil
    }

    /// 刪除最後輸入的注音符號（Backspace 行為）
    /// - Returns: 刪除後是否還有剩餘內容
    @discardableResult
    public func deleteLast() -> Bool {
        isComplete = false
        if tone != nil {
            tone = nil
            return true
        }
        if final_ != nil {
            final_ = nil
            return true
        }
        if medial != nil {
            medial = nil
            return true
        }
        if initial != nil {
            initial = nil
            return false
        }
        return false
    }

    /// 處理單一按鍵（字元）
    /// - Parameter key: 使用者按下的字元（小寫）
    /// - Returns: 處理結果
    @discardableResult
    public func handle(key: Character) -> HandleResult {
        // 1. 聲調鍵（6/3/4/7）
        if let t = Self.keyToTone[key] {
            // 必須有至少一個聲母/介音/韻母才算合法
            if isEmpty { return .notBopomofo }
            tone = t
            isComplete = true
            return .syllableComplete
        }

        // 2. 空白鍵 = 一聲（隱含）
        if key == " " {
            if isEmpty { return .notBopomofo }
            tone = nil   // 一聲不顯示聲調符號
            isComplete = true
            return .syllableComplete
        }

        // 3. 注音符號鍵
        guard let bopomofo = Self.keyToBopomofo[key] else {
            return .notBopomofo
        }

        if Self.initials.contains(bopomofo) {
            // 若已有完整注音但未完成（不應發生），清空後重新開始
            initial = bopomofo
            medial = nil
            final_ = nil
            tone = nil
            isComplete = false
        } else if Self.medials.contains(bopomofo) {
            medial = bopomofo
        } else if Self.finals.contains(bopomofo) {
            final_ = bopomofo
        }
        return .consumed
    }

    /// 轉為注音字串（用於字典查詢）
    /// 例：ㄋㄧˇ（含聲調）或 ㄋㄧ（一聲，無聲調符號）
    public var bopomofoString: String {
        var result = ""
        if let c = initial  { result.append(c) }
        if let c = medial   { result.append(c) }
        if let c = final_   { result.append(c) }
        if let c = tone     { result.append(c) }
        return result
    }

    /// 轉為顯示字串（供 UI 顯示，含聲調）
    public var displayString: String {
        return bopomofoString
    }
}

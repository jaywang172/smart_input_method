import Foundation

/// SmartIME 輸入法狀態機
///
/// 輸入法是一個有限狀態機（FSM），狀態物件為 immutable。
/// 每次狀態改變都建立新物件，由 SmartInputController 持有當前狀態。
///
/// 狀態流程：
/// ```
/// empty ←→ composing ←→ choosingCandidate
///                ↘
///            (Enter/Space) → commit → empty
/// ```
enum IMEState: Equatable {

    /// 無輸入狀態：輸入法已啟動，但緩衝區空白
    case empty

    /// 組字中：使用者正在輸入注音，composingBuffer 為已確認的漢字序列，
    /// syllable 為當前音節的注音顯示字串（可能是 "" 或部分注音）
    case composing(buffer: String, syllable: String)

    /// 選字中：當使用者按 ↓ 或 Space(在有選項時) 觸發候選字窗
    /// buffer = 已確認部分, syllableReading = 當前音節注音, candidates = 候選清單
    case choosingCandidate(buffer: String, syllableReading: String, candidates: [String])

    // MARK: - Computed Properties

    /// 完整的組字字串（用於 setMarkedText）
    var composingBuffer: String {
        switch self {
        case .empty:
            return ""
        case .composing(let buf, let syl):
            return buf + syl
        case .choosingCandidate(let buf, let syl, _):
            return buf + syl
        }
    }

    /// 是否為空狀態
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    /// 是否有任何輸入內容
    var hasContent: Bool {
        return !composingBuffer.isEmpty
    }

    static func == (lhs: IMEState, rhs: IMEState) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): return true
        case (.composing(let b1, let s1), .composing(let b2, let s2)):
            return b1 == b2 && s1 == s2
        case (.choosingCandidate(let b1, let s1, let c1), .choosingCandidate(let b2, let s2, let c2)):
            return b1 == b2 && s1 == s2 && c1 == c2
        default: return false
        }
    }
}

import Foundation

/// 讀多寫少鎖 + 不可變快照，用於保護 InputEngine 狀態
final class ThreadSafeSnapshot<T> {
    private var _value: T
    private var rwlock = pthread_rwlock_t()
    
    init(_ initialValue: T) {
        _value = initialValue
        pthread_rwlock_init(&rwlock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&rwlock)
    }
    
    /// 讀取快照（多執行緒安全）
    func read<U>(_ block: (T) -> U) -> U {
        pthread_rwlock_rdlock(&rwlock)
        defer { pthread_rwlock_unlock(&rwlock) }
        return block(_value)
    }
    
    /// 寫入（獨占鎖）
    @discardableResult
    func write<U>(_ block: (inout T) -> U) -> U {
        pthread_rwlock_wrlock(&rwlock)
        defer { pthread_rwlock_unlock(&rwlock) }
        return block(&_value)
    }
    
    /// 獲取不可變快照
    func snapshot() -> T {
        return read { $0 }
    }
}

/// 輸入狀態快照（不可變）
struct InputStateSnapshot {
    let inputBuffer: String
    let contextWords: [String]
    let candidates: [InputEngine.Candidate]
    
    init(inputBuffer: String, contextWords: [String], candidates: [InputEngine.Candidate]) {
        self.inputBuffer = inputBuffer
        self.contextWords = contextWords
        self.candidates = candidates
    }
}

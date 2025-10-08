import Foundation

/// 統一詞查詢介面，便於以壓縮 Trie 替換
protocol WordLookup {
    func insert(_ word: String, frequency: Int)
    func insertBatch(_ words: [(String, Int)])
    func search(_ word: String) -> Bool
    func startsWith(_ prefix: String) -> Bool
    func getAllWordsWithPrefix(_ prefix: String, limit: Int) -> [(word: String, frequency: Int)]
    var count: Int { get }
    func clear()
}



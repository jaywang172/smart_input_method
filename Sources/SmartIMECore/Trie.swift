import Foundation

/// Trie（前綴樹）節點
public class TrieNode {
    public var children: [Character: TrieNode] = [:]
    public var isEndOfWord: Bool = false
    public var frequency: Int = 0
    public var word: String?
    
    public init() {}
}

/// Trie 資料結構 - 用於快速詞彙查找和自動補全
/// 時間複雜度：插入 O(m)，查找 O(m)，m 為詞長度
public class Trie: WordLookup {
    private let root = TrieNode()
    private var wordCount = 0
    
    public init() {}
    
    /// 插入一個詞到 Trie 中
    /// - Parameters:
    ///   - word: 要插入的詞
    ///   - frequency: 詞的使用頻率
    public func insert(_ word: String, frequency: Int = 1) {
        var current = root
        
        for char in word {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }
        
        let wasEnd = current.isEndOfWord
        current.isEndOfWord = true
        current.frequency += frequency
        current.word = word
        if !wasEnd { wordCount += 1 }
    }
    
    /// 搜尋一個詞是否存在
    /// - Parameter word: 要搜尋的詞
    /// - Returns: 是否存在
    public func search(_ word: String) -> Bool {
        guard let node = findNode(word) else { return false }
        return node.isEndOfWord
    }
    
    /// 查找前綴
    /// - Parameter prefix: 前綴字串
    /// - Returns: 是否存在該前綴
    public func startsWith(_ prefix: String) -> Bool {
        return findNode(prefix) != nil
    }
    
    /// 獲取所有以指定前綴開始的詞
    /// - Parameters:
    ///   - prefix: 前綴字串
    ///   - limit: 返回結果的最大數量
    /// - Returns: 按頻率排序的詞列表
    public func getAllWordsWithPrefix(_ prefix: String, limit: Int = 10) -> [(word: String, frequency: Int)] {
        guard let node = findNode(prefix) else { return [] }
        
        var results: [(String, Int)] = []
        collectWords(from: node, prefix: prefix, results: &results)
        
        // 按頻率降序排序
        results.sort { $0.1 > $1.1 }
        
        return Array(results.prefix(limit))
    }
    
    /// 查找節點
    private func findNode(_ str: String) -> TrieNode? {
        var current = root
        
        for char in str {
            guard let next = current.children[char] else {
                return nil
            }
            current = next
        }
        
        return current
    }
    
    /// 收集所有詞（DFS）
    private func collectWords(from node: TrieNode, prefix: String, results: inout [(String, Int)]) {
        if node.isEndOfWord, let word = node.word {
            results.append((word, node.frequency))
        }
        
        for (char, childNode) in node.children {
            collectWords(from: childNode, prefix: prefix + String(char), results: &results)
        }
    }
    
    /// 獲取 Trie 中的總詞數
    public var count: Int {
        return wordCount
    }
    
    /// 清空 Trie
    public func clear() {
        root.children.removeAll()
        wordCount = 0
    }
}

// MARK: - Trie Extensions

extension Trie {
    /// 批量插入詞彙
    /// - Parameter words: 詞彙數組，每個元素為 (詞, 頻率)
    public func insertBatch(_ words: [(String, Int)]) {
        for (word, frequency) in words {
            insert(word, frequency: frequency)
        }
    }
    
    /// 從檔案加載詞典
    /// - Parameter filePath: 詞典檔案路徑（每行格式：詞 頻率）
    /// - Throws: 檔案讀取錯誤
    public func loadFromFile(_ filePath: String) throws {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let components = line.components(separatedBy: .whitespaces)
            guard components.count >= 1, !components[0].isEmpty else { continue }
            
            let word = components[0]
            let frequency = components.count > 1 ? Int(components[1]) ?? 1 : 1
            insert(word, frequency: frequency)
        }
    }
}

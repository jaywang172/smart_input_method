import Foundation

/// 壓縮前綴樹（Radix Trie / Patricia Trie）
public final class RadixTrie: WordLookup {
    final class Node {
        var children: [String: Node] = [:]
        var isEndOfWord: Bool = false
        var frequency: Int = 0
        var word: String?
    }

    private let root = Node()
    private var wordCount = 0
    private var prefixCache = LRUCache<String, [(String, Int)]>(capacity: 2048)
    
    public init() {}

    public func insert(_ word: String, frequency: Int = 1) {
        guard !word.isEmpty else { return }
        var current = root
        var key = word
        while true {
            // 在 children 中尋找具有共同前綴的邊
            if let (edge, child) = current.children.first(where: { key.hasPrefixCommon(with: $0.key) }) {
                let lcp = key.longestCommonPrefix(with: edge)
                if lcp.count == edge.count {
                    // 完全匹配邊，向下走
                    key.removeFirst(lcp.count)
                    current = child
                    if key.isEmpty { break }
                    continue
                } else {
                    // 分裂邊：edge -> lcp + remainder
                    let remainder = String(edge.dropFirst(lcp.count))
                    let splitNode = Node()
                    splitNode.children[remainder] = child
                    current.children.removeValue(forKey: edge)
                    current.children[lcp] = splitNode
                    current = splitNode
                    key.removeFirst(lcp.count)
                    if key.isEmpty { current = splitNode ; break }
                    continue
                }
            } else {
                // 無共同前綴，直接新增邊
                let newNode = Node()
                current.children[key] = newNode
                current = newNode
                break
            }
        }
        let wasEnd = current.isEndOfWord
        current.isEndOfWord = true
        current.frequency += frequency
        current.word = word
        if !wasEnd { wordCount += 1 }
        prefixCache.removeAll()
    }

    func insertBatch(_ words: [(String, Int)]) {
        for (w, f) in words { insert(w, frequency: f) }
    }

    public func search(_ word: String) -> Bool {
        return findNode(word)?.isEndOfWord ?? false
    }

    func startsWith(_ prefix: String) -> Bool {
        return findNode(prefix) != nil
    }

    func getAllWordsWithPrefix(_ prefix: String, limit: Int = 10) -> [(word: String, frequency: Int)] {
        if let cached = prefixCache.get(prefix) { return Array(cached.prefix(limit)) }
        guard let (node, consumed) = findNodeWithConsumed(prefix) else { return [] }
        var results: [(String, Int)] = []
        collect(from: node, prefix: String(prefix.prefix(consumed)), carry: String(prefix.dropFirst(consumed)), acc: &results)
        results.sort { $0.1 > $1.1 }
        let sliced = Array(results.prefix(limit))
        prefixCache.set(prefix, value: sliced)
        return sliced
    }

    var count: Int { wordCount }

    func clear() {
        root.children.removeAll()
        wordCount = 0
        prefixCache.removeAll()
    }

    private func findNode(_ str: String) -> Node? {
        return findNodeWithConsumed(str)?.0
    }

    private func findNodeWithConsumed(_ str: String) -> (Node, Int)? {
        var current = root
        var key = str
        var consumed = 0
        while !key.isEmpty {
            if let (edge, child) = current.children.first(where: { key.hasPrefixCommon(with: $0.key) }) {
                let lcp = key.longestCommonPrefix(with: edge)
                if lcp.count == edge.count {
                    key.removeFirst(lcp.count)
                    consumed += lcp.count
                    current = child
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        return (current, consumed)
    }

    private func collect(from node: Node, prefix: String, carry: String, acc: inout [(String, Int)]) {
        if node.isEndOfWord, let w = node.word {
            acc.append((w, node.frequency))
        }
        for (edge, child) in node.children {
            collect(from: child, prefix: prefix + carry, carry: edge, acc: &acc)
        }
    }
}

// MARK: - Helpers

private extension String {
    func hasPrefixCommon(with other: String) -> Bool {
        return !self.longestCommonPrefix(with: other).isEmpty
    }
    func longestCommonPrefix(with other: String) -> String {
        let a = Array(self)
        let b = Array(other)
        var i = 0
        while i < a.count && i < b.count {
            if a[i] != b[i] { break }
            i += 1
        }
        return String(a.prefix(i))
    }
}

// 簡易 LRU 快取（執行緒不安全；由呼叫方保護）
final class LRUCache<K: Hashable, V> {
    private let capacity: Int
    private var dict: [K: V] = [:]
    private var order: [K] = []

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func get(_ key: K) -> V? {
        if let v = dict[key] {
            if let idx = order.firstIndex(of: key) { order.remove(at: idx) }
            order.insert(key, at: 0)
            return v
        }
        return nil
    }

    func set(_ key: K, value: V) {
        dict[key] = value
        if let idx = order.firstIndex(of: key) { order.remove(at: idx) }
        order.insert(key, at: 0)
        if order.count > capacity {
            let k = order.removeLast()
            dict.removeValue(forKey: k)
        }
    }

    func removeAll() {
        dict.removeAll()
        order.removeAll()
    }
}



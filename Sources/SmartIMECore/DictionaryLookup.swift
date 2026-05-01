import Foundation

/// 字典查詢器：注音序列 → 中文候選詞
/// 基於 truly_smart_input.swift 的驗證邏輯
class DictionaryLookup {
    
    // 注音到中文的映射字典
    private var dictionary: [String: [String]] = [:]
    
    /// 初始化
    init() {
        loadDefaultDictionary()
    }
    
    /// 載入預設字典
    private func loadDefaultDictionary() {
        // 基本字典（從 truly_smart_input.swift 驗證的映射）
        dictionary = [
            // 單字
            "ㄋㄧˇ": ["你", "尼", "泥"],
            "ㄏㄠˇ": ["好", "號", "豪"],
            "ㄨㄛˇ": ["我", "握", "臥"],
            "ㄨˇ": ["我", "握", "臥"],  // 簡化版（j3）
            "ㄏㄣˇ": ["很", "狠", "恨"],
            "ㄊㄚ": ["他", "她", "它"],
            "ㄇㄣˊ": ["們", "門", "悶"],
            "ㄐㄧㄣ": ["今", "金", "進"],
            "ㄊㄧㄢ": ["天", "添", "田"],
            "ㄑㄧˋ": ["氣", "器", "棄"],
            "ㄓㄣ": ["真", "珍", "針"],
            
            // 組合詞
            "ㄋㄧˇㄏㄠˇ": ["你好", "尼好"],
            "ㄨㄛˇㄏㄣˇ": ["我很"],
            "ㄏㄣˇㄏㄠˇ": ["很好"],
            "ㄊㄧㄢㄑㄧˋ": ["天氣"],
            "ㄓㄣㄏㄠˇ": ["真好"],
            "ㄐㄧㄣㄊㄧㄢ": ["今天"],
            "ㄑㄧˋㄓㄣ": ["氣真"],
            
            // 常用詞（擴展）
            "ㄕˋ": ["是", "事", "室", "世", "士"],
            "ㄓㄨㄥ": ["中", "終", "鐘", "忠"],
            "ㄨㄣˊ": ["文", "聞", "紋"],
            "ㄇㄥˊ": ["萌", "盟", "檬"]
        ]
    }
    
    /// 從外部 JSON 文件載入字典（未來優化）
    func loadFromJSON(_ path: String) {
        // TODO: 實現從 JSON 文件載入
    }
    
    /// 查詢注音序列
    /// - Parameter bopomofoSequence: 注音序列（例如："ㄋㄧˇㄏㄠˇ"）
    /// - Returns: 候選詞列表，如果找不到則返回 nil
    func lookup(_ bopomofoSequence: String) -> [String]? {
        // 1. 直接查找完整的注音序列
        if let candidates = dictionary[bopomofoSequence] {
            return candidates
        }
        
        // 2. 嘗試分詞查找（處理空格分隔的注音）
        if bopomofoSequence.contains(" ") {
            return segmentWithSpaces(bopomofoSequence)
        }
        
        // 3. 嘗試動態分詞
        return segment(bopomofoSequence)
    }
    
    /// 使用空格分詞
    private func segmentWithSpaces(_ sequence: String) -> [String]? {
        let parts = sequence.split(separator: " ")
        var results: [String] = []
        
        for part in parts {
            if let candidates = dictionary[String(part)] {
                results.append(candidates.first ?? String(part))
            } else {
                // 如果某個部分找不到，嘗試繼續分詞
                if let segmented = segment(String(part)) {
                    results.append(contentsOf: segmented)
                } else {
                    return nil
                }
            }
        }
        
        return results.isEmpty ? nil : results
    }
    
    /// 動態分詞算法
    /// 使用貪婪算法從最長的注音序列開始匹配
    private func segment(_ sequence: String) -> [String]? {
        guard !sequence.isEmpty else { return [] }
        
        var result: [String] = []
        var remaining = sequence
        
        // 按長度排序字典鍵（從長到短）
        let sortedKeys = dictionary.keys.sorted { $0.count > $1.count }
        
        while !remaining.isEmpty {
            var matched = false
            
            // 嘗試從最長的注音序列開始匹配
            for key in sortedKeys {
                if remaining.hasPrefix(key) {
                    if let candidates = dictionary[key] {
                        result.append(candidates.first ?? key)
                        remaining = String(remaining.dropFirst(key.count))
                        matched = true
                        break
                    }
                }
            }
            
            if !matched {
                // 無法匹配，返回 nil
                return nil
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    /// 檢查注音序列是否有效（是否可以在字典中找到）
    /// - Parameter bopomofoSequence: 注音序列
    /// - Returns: 是否為有效注音
    func isValidBopomofo(_ bopomofoSequence: String) -> Bool {
        return lookup(bopomofoSequence) != nil
    }
    
    /// 添加新的映射到字典
    /// - Parameters:
    ///   - bopomofo: 注音序列
    ///   - candidates: 候選詞列表
    func addMapping(bopomofo: String, candidates: [String]) {
        dictionary[bopomofo] = candidates
    }
    
    /// 獲取字典大小
    func getDictionarySize() -> Int {
        return dictionary.count
    }
}

// MARK: - 使用範例

/*
let lookup = DictionaryLookup()

// 範例 1: 直接查找
if let candidates = lookup.lookup("ㄋㄧˇㄏㄠˇ") {
    print("ㄋㄧˇㄏㄠˇ → \(candidates)")  // ["你好", "尼好"]
}

// 範例 2: 空格分詞
if let candidates = lookup.lookup("ㄐㄧㄣ ㄊㄧㄢ") {
    print("ㄐㄧㄣ ㄊㄧㄢ → \(candidates)")  // ["今", "天"]
}

// 範例 3: 動態分詞
if let candidates = lookup.lookup("ㄋㄧˇㄏㄠˇㄨㄛˇ") {
    print("ㄋㄧˇㄏㄠˇㄨㄛˇ → \(candidates)")  // ["你好", "我"]
}

// 範例 4: 檢查是否為有效注音
print(lookup.isValidBopomofo("ㄋㄧˇㄏㄠˇ"))  // true
print(lookup.isValidBopomofo("ㄘㄍㄠㄠㄟ"))  // false (hello 的注音)
*/

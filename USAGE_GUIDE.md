# 使用指南

## 快速開始

### 1. 基本使用

```swift
import Foundation

// 創建輸入引擎實例
let engine = InputEngine()

// 處理使用者輸入
let candidates = engine.handleInput("ㄋㄧˇㄏㄠˇ")

// 顯示候選詞
for (index, candidate) in candidates.enumerated() {
    print("\(index + 1). \(candidate.text) (分數: \(candidate.score))")
}

// 選擇候選詞
engine.selectCandidate(at: 0)
```

### 2. 語言檢測

```swift
let detector = LanguageDetector()

// 檢測輸入語言
let result = detector.detect("hello world")
print("檢測結果: \(result.language)")
print("信心度: \(result.confidence)")

// 帶上下文的檢測
let contextResult = detector.detect("test", context: "我在學習")
print("上下文檢測: \(contextResult.language)")
```

### 3. 注音轉中文

```swift
let ngramModel = NgramModel()
let trie = Trie()
let converter = BopomofoConverter(ngramModel: ngramModel, trie: trie)

// 基本轉換
let candidates = converter.convert("ㄋㄧˇㄏㄠˇ")
print("候選詞: \(candidates)")

// 帶上下文的轉換
let contextCandidates = converter.convertWithContext(
    "ㄏㄠˇ",
    context: ["你"]
)
print("上下文候選: \(contextCandidates)")

// Viterbi 轉換
let bopomofoSequence = ["ㄋㄧˇ", "ㄏㄠˇ"]
let result = converter.viterbiConvert(bopomofoSequence)
print("Viterbi 結果: \(result)")
```

### 4. Trie 樹操作

```swift
let trie = Trie()

// 插入詞彙
trie.insert("apple", frequency: 100)
trie.insert("application", frequency: 80)
trie.insert("apply", frequency: 90)

// 搜尋
if trie.search("apple") {
    print("找到 'apple'")
}

// 前綴查找
let matches = trie.getAllWordsWithPrefix("app", limit: 5)
for (word, frequency) in matches {
    print("\(word): \(frequency)")
}

// 批量插入
let words = [
    ("hello", 100),
    ("world", 90),
    ("swift", 85)
]
trie.insertBatch(words)

// 從檔案加載
try? trie.loadFromFile("/path/to/dictionary.txt")
```

### 5. N-gram 模型訓練

```swift
let model = NgramModel()

// 準備訓練語料
let corpus = [
    ["今天", "天氣", "很好"],
    ["我", "喜歡", "編程"],
    ["Swift", "是", "很棒", "的", "語言"]
]

// 訓練模型
model.train(corpus: corpus)

// 計算機率
let unigramProb = model.unigramProbability("天氣")
let bigramProb = model.bigramProbability("今天", "天氣")
let trigramProb = model.trigramProbability("今天", "天氣", "很好")

print("P(天氣) = \(unigramProb)")
print("P(天氣|今天) = \(bigramProb)")
print("P(很好|今天,天氣) = \(trigramProb)")

// 預測下一個詞
let candidates = ["很好", "不好", "晴朗"]
let predictions = model.predictNext(context: ["今天", "天氣"], candidates: candidates)

for (word, prob) in predictions {
    print("\(word): \(String(format: "%.4f", prob))")
}

// 保存和加載模型
try? model.save(to: "/path/to/model.json")
try? model.load(from: "/path/to/model.json")
```

### 6. 機器學習分類器

```swift
let classifier = LanguageClassifier()

// 準備訓練數據
let trainingData: [(String, LanguageClassifier.LanguageType)] = [
    ("你好", .chinese),
    ("世界", .chinese),
    ("hello", .english),
    ("world", .english),
    ("輸入法", .chinese),
    ("keyboard", .english),
]

// 訓練分類器
classifier.train(samples: trainingData)

// 分類新輸入
let result = classifier.classify("測試")
print("語言: \(result.language.rawValue)")
print("機率: \(result.probability)")
print("所有機率: \(result.allProbabilities)")

// 增量學習
classifier.learn(text: "program", correctLanguage: .english)

// 保存和加載模型
try? classifier.saveModel(to: "/path/to/classifier.json")
try? classifier.loadModel(from: "/path/to/classifier.json")
```

## 進階使用

### 1. 自定義詞典

創建詞典檔案 `custom_dict.txt`:

```
你好 1000
世界 800
輸入法 600
Swift 500
程式設計 450
```

加載自定義詞典:

```swift
let trie = Trie()
try trie.loadFromFile("custom_dict.txt")
```

### 2. 添加自定義注音映射

```swift
let converter = BopomofoConverter(ngramModel: model, trie: trie)

// 添加自定義映射
converter.addMapping(bopomofo: "ㄎㄨˋ", chinese: "酷")
converter.addMapping(bopomofo: "ㄌㄚˋ", chinese: "辣")

// 從檔案加載
try converter.loadDictionary(from: "/path/to/bopomofo_dict.txt")
```

注音詞典檔案格式 (tab 分隔):

```
你	ㄋㄧˇ
好	ㄏㄠˇ
你好	ㄋㄧˇㄏㄠˇ
```

### 3. 上下文感知輸入

```swift
let engine = InputEngine()

// 模擬連續輸入
let sequence = [
    "今天",
    "天氣",
    "很好"
]

for word in sequence {
    let candidates = engine.handleInput(word)
    
    // 選擇第一個候選詞
    if !candidates.isEmpty {
        engine.selectCandidate(at: 0)
    }
}

// 獲取基於上下文的建議
let suggestions = engine.getSuggestions(limit: 5)
print("下一個詞建議: \(suggestions)")

// 查看當前上下文
print("當前上下文: \(engine.currentContext)")
```

### 4. 批量處理

```swift
let engine = InputEngine()

let inputs = ["ㄋㄧˇㄏㄠˇ", "hello", "ㄨㄛˇ"]

for input in inputs {
    let candidates = engine.handleInput(input)
    
    print("\n輸入: \(input)")
    print("候選詞:")
    
    for (index, candidate) in candidates.prefix(3).enumerated() {
        let source = candidate.source
        print("  \(index + 1). \(candidate.text) [\(source)]")
    }
    
    engine.clearInput()
}
```

### 5. 學習新詞

```swift
let engine = InputEngine()

// 學習中文新詞
engine.learnWord("ChatGPT", language: .chinese)
engine.learnWord("人工智慧", language: .chinese)

// 學習英文新詞
engine.learnWord("swift", language: .english)
engine.learnWord("programming", language: .english)

// 查看統計資訊
let stats = engine.getStatistics()
print("統計資訊: \(stats)")
```

### 6. 性能測試

```swift
import Foundation

func benchmarkTrie() {
    let trie = Trie()
    let words = (1...10000).map { "word\($0)" }
    
    // 測試插入性能
    let startInsert = Date()
    for word in words {
        trie.insert(word, frequency: Int.random(in: 1...100))
    }
    let insertTime = Date().timeIntervalSince(startInsert)
    print("插入 10,000 詞耗時: \(insertTime) 秒")
    
    // 測試查找性能
    let startSearch = Date()
    for word in words.prefix(1000) {
        _ = trie.search(word)
    }
    let searchTime = Date().timeIntervalSince(startSearch)
    print("查找 1,000 詞耗時: \(searchTime) 秒")
    print("平均查找時間: \(searchTime / 1000) 秒/詞")
}

func benchmarkNgram() {
    let model = NgramModel()
    
    // 生成大量訓練數據
    let corpus = (1...1000).map { _ in
        (1...10).map { "word\($0)" }
    }
    
    let startTrain = Date()
    model.train(corpus: corpus)
    let trainTime = Date().timeIntervalSince(startTrain)
    print("訓練耗時: \(trainTime) 秒")
    
    // 測試查詢性能
    let startQuery = Date()
    for _ in 1...1000 {
        _ = model.bigramProbability("word1", "word2")
    }
    let queryTime = Date().timeIntervalSince(startQuery)
    print("1,000 次查詢耗時: \(queryTime) 秒")
}

benchmarkTrie()
benchmarkNgram()
```

## 錯誤處理

```swift
do {
    // 嘗試加載檔案
    try trie.loadFromFile("dictionary.txt")
} catch {
    print("無法加載詞典: \(error)")
    // 使用預設詞典
}

do {
    // 嘗試保存模型
    try model.save(to: "model.json")
} catch {
    print("無法保存模型: \(error)")
}
```

## 最佳實踐

### 1. 初始化

```swift
// 在應用啟動時初始化引擎
class IMEManager {
    static let shared = IMEManager()
    let engine: InputEngine
    
    private init() {
        engine = InputEngine()
        // 加載資源
        loadResources()
    }
    
    private func loadResources() {
        // 異步加載大型詞典
        DispatchQueue.global(qos: .userInitiated).async {
            // 加載詞典和模型
        }
    }
}
```

### 2. 記憶體管理

```swift
// 定期清理不常用的數據
func cleanupCache() {
    engine.reset()
    // 清理其他緩存
}

// 在收到記憶體警告時
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: nil
) { _ in
    cleanupCache()
}
```

### 3. 線程安全

```swift
// 使用串行隊列保證線程安全
class ThreadSafeInputEngine {
    private let engine = InputEngine()
    private let queue = DispatchQueue(label: "com.ime.engine")
    
    func handleInput(_ input: String, completion: @escaping ([InputEngine.Candidate]) -> Void) {
        queue.async {
            let candidates = self.engine.handleInput(input)
            DispatchQueue.main.async {
                completion(candidates)
            }
        }
    }
}
```

## 常見問題

### Q: 如何提高轉換準確度？

A: 
1. 使用更大的訓練語料
2. 調整 N-gram 模型的平滑參數
3. 增加使用者個性化學習
4. 使用更複雜的深度學習模型

### Q: 如何處理生僻字？

A:
1. 在詞典中添加生僻字
2. 降低頻率閾值
3. 提供手動輸入選項

### Q: 如何優化性能？

A:
1. 使用延遲加載
2. 實現緩存機制
3. 使用索引加速查找
4. 多線程並行處理

### Q: 如何支持更多語言？

A:
1. 擴展 Language 枚舉
2. 為每種語言創建專門的 Trie
3. 訓練多語言分類器
4. 添加語言特定的特徵提取器

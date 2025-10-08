# 快速參考指南

## 專案統計

- **總程式碼行數**: ~2000 行
- **Swift 檔案**: 9 個
- **文檔檔案**: 5 個
- **核心模組**: 6 個
- **演算法**: 5+ 個

## 核心類別快速參考

### 1. InputEngine (輸入引擎)

```swift
let engine = InputEngine()

// 處理輸入
let candidates = engine.handleInput("ㄋㄧˇ")

// 選擇候選詞
engine.selectCandidate(at: 0)

// 刪除字符
engine.deleteLastCharacter()

// 清空輸入
engine.clearInput()

// 重置引擎
engine.reset()

// 獲取建議
let suggestions = engine.getSuggestions(limit: 5)
```

### 2. Trie (前綴樹)

```swift
let trie = Trie()

// 插入詞彙
trie.insert("word", frequency: 100)

// 搜尋
let found = trie.search("word")  // Bool

// 前綴匹配
let hasPrefix = trie.startsWith("wo")  // Bool

// 獲取所有匹配
let matches = trie.getAllWordsWithPrefix("wo", limit: 10)
// [(word: String, frequency: Int)]

// 批量插入
trie.insertBatch([("word1", 100), ("word2", 90)])

// 從檔案加載
try trie.loadFromFile("dict.txt")
```

### 3. NgramModel (語言模型)

```swift
let model = NgramModel()

// 訓練
let corpus = [["我", "愛", "你"], ["你", "好", "嗎"]]
model.train(corpus: corpus)

// 計算機率
let p1 = model.unigramProbability("我")
let p2 = model.bigramProbability("我", "愛")
let p3 = model.trigramProbability("我", "愛", "你")

// 預測下一個詞
let predictions = model.predictNext(
    context: ["我", "愛"],
    candidates: ["你", "她", "他"]
)

// 句子機率
let prob = model.sentenceProbability(["我", "愛", "你"])

// 保存/加載
try model.save(to: "model.json")
try model.load(from: "model.json")
```

### 4. BopomofoConverter (注音轉換器)

```swift
let converter = BopomofoConverter(ngramModel: model, trie: trie)

// 基本轉換
let candidates = converter.convert("ㄋㄧˇㄏㄠˇ")
// [(word: String, score: Double)]

// 帶上下文轉換
let contextCandidates = converter.convertWithContext(
    "ㄏㄠˇ",
    context: ["你"]
)

// Viterbi 演算法
let sequence = ["ㄋㄧˇ", "ㄏㄠˇ"]
let result = converter.viterbiConvert(sequence)
// ["你", "好"]

// 添加映射
converter.addMapping(bopomofo: "ㄋㄧˇ", chinese: "你")

// 加載詞典
try converter.loadDictionary(from: "bopomofo_dict.txt")
```

### 5. LanguageDetector (語言檢測器)

```swift
let detector = LanguageDetector()

// 檢測語言
let result = detector.detect("hello")
// result.language: .english
// result.confidence: 0.95
// result.features: [String: Double]

// 帶上下文檢測
let contextResult = detector.detect("test", context: "我在學習")

// 清除歷史
detector.clearHistory()
```

### 6. LanguageClassifier (ML 分類器)

```swift
let classifier = LanguageClassifier()

// 訓練
let samples = [
    ("你好", .chinese),
    ("hello", .english)
]
classifier.train(samples: samples)

// 分類
let result = classifier.classify("測試")
// result.language: .chinese
// result.probability: 0.92
// result.allProbabilities: [.chinese: 0.92, .english: 0.08]

// 增量學習
classifier.learn(text: "world", correctLanguage: .english)

// 保存/加載
try classifier.saveModel(to: "classifier.json")
try classifier.loadModel(from: "classifier.json")
```

## 演算法複雜度速查

| 演算法/操作 | 時間複雜度 | 空間複雜度 |
|------------|-----------|-----------|
| Trie 插入 | O(m) | O(m) |
| Trie 查找 | O(m) | O(1) |
| Trie 前綴匹配 | O(m + k) | O(k) |
| N-gram 訓練 | O(n × l) | O(V²) |
| N-gram 查詢 | O(1) | O(1) |
| Viterbi | O(n × s²) | O(n × s) |
| 動態規劃分段 | O(n² × k) | O(n × k) |
| 語言檢測 | O(n) | O(1) |
| 貝葉斯分類 | O(f) | O(f) |

註: m=詞長, k=結果數, n=序列長, s=狀態數, l=句子平均長度, V=詞彙量, f=特徵數

## 常用程式碼片段

### 完整輸入流程

```swift
// 1. 初始化
let engine = InputEngine()

// 2. 處理輸入序列
let inputs = ["ㄋㄧˇ", "ㄏㄠˇ", "ㄕˋ", "ㄐㄧㄝˋ"]

for input in inputs {
    // 輸入字符
    let candidates = engine.handleInput(input)
    
    // 顯示候選詞
    print("候選詞:")
    for (i, candidate) in candidates.prefix(5).enumerated() {
        print("\(i+1). \(candidate.text)")
    }
    
    // 選擇第一個
    if !candidates.isEmpty {
        engine.selectCandidate(at: 0)
    }
}

// 3. 獲取上下文建議
let suggestions = engine.getSuggestions()
print("建議: \(suggestions)")
```

### 建立自定義詞典

```swift
// 創建詞典檔案
let dictionary = """
你好 1000
世界 800
輸入法 600
Swift 500
"""

// 保存到檔案
try dictionary.write(toFile: "dict.txt", atomically: true, encoding: .utf8)

// 加載到 Trie
let trie = Trie()
try trie.loadFromFile("dict.txt")
```

### 訓練自定義模型

```swift
// 準備語料
let corpus = [
    ["今天", "天氣", "很好"],
    ["我", "喜歡", "Swift"],
    ["輸入法", "很", "智能"]
]

// 訓練模型
let model = NgramModel()
model.train(corpus: corpus)

// 測試模型
let prob = model.bigramProbability("今天", "天氣")
print("P(天氣|今天) = \(prob)")
```

### 性能測試模板

```swift
func benchmark(_ name: String, iterations: Int = 1000, _ block: () -> Void) {
    let start = Date()
    for _ in 0..<iterations {
        block()
    }
    let elapsed = Date().timeIntervalSince(start)
    print("\(name): \(elapsed)s (\(elapsed/Double(iterations))s/次)")
}

// 使用
benchmark("Trie 查找", iterations: 10000) {
    _ = trie.search("test")
}
```

## 檔案格式說明

### 詞典檔案格式 (dict.txt)

```
詞彙 頻率
你好 1000
世界 800
```

### 注音映射檔案格式 (bopomofo.txt)

```
中文字<TAB>注音
你<TAB>ㄋㄧˇ
好<TAB>ㄏㄠˇ
```

### 訓練語料格式

```json
{
  "corpus": [
    ["我", "愛", "你"],
    ["今天", "天氣", "很好"]
  ]
}
```

## 常見問題快速解答

### Q: 如何提高轉換準確度？
```swift
// 1. 使用更大的訓練語料
let largeCorpus = loadCorpusFromFile("large_corpus.txt")
model.train(corpus: largeCorpus)

// 2. 調整平滑參數（修改 NgramModel.swift）
// private let smoothingFactor: Double = 0.01  // 調整這個值

// 3. 使用上下文
let candidates = converter.convertWithContext(input, context: previousWords)
```

### Q: 如何添加自定義詞？
```swift
// 方法1: 直接添加
engine.learnWord("新詞", language: .chinese)

// 方法2: 添加到 Trie
trie.insert("新詞", frequency: 100)

// 方法3: 添加注音映射
converter.addMapping(bopomofo: "ㄒㄧㄣ", chinese: "新")
```

### Q: 如何優化性能？
```swift
// 1. 批量操作
let words = [("word1", 100), ("word2", 90)]
trie.insertBatch(words)

// 2. 限制候選詞數量
let candidates = trie.getAllWordsWithPrefix("pre", limit: 5)

// 3. 使用緩存
var cache: [String: [String]] = [:]
if let cached = cache[input] {
    return cached
}
```

## 除錯技巧

### 查看內部狀態

```swift
// 輸入引擎狀態
print("當前輸入: \(engine.currentInput)")
print("上下文: \(engine.currentContext)")
print("統計: \(engine.getStatistics())")

// 模型資訊
print("模型資訊: \(classifier.getModelInfo())")
print("常見詞: \(model.topWords(n: 10))")
```

### 測試特定功能

```swift
// 測試 Trie
assert(trie.search("word"), "應該找到 word")

// 測試 N-gram
let prob = model.unigramProbability("test")
assert(prob > 0, "機率應該大於 0")

// 測試語言檢測
let result = detector.detect("hello")
assert(result.language == .english, "應該檢測為英文")
```

## 擴展建議

### 添加新語言支援

```swift
// 1. 擴展 Language 枚舉
enum Language {
    case chinese
    case english
    case japanese  // 新增
    case korean    // 新增
}

// 2. 為新語言創建 Trie
let japaneseTrie = Trie()

// 3. 更新檢測器
// 在 LanguageDetector 中添加新語言的特徵
```

### 添加深度學習模型

```swift
// 1. 導入 CoreML
import CoreML

// 2. 加載模型
let model = try MLModel(contentsOf: modelURL)

// 3. 預測
let prediction = try model.prediction(from: input)
```

## 資源連結

- [Swift 官方文檔](https://swift.org/documentation/)
- [自然語言處理基礎](https://web.stanford.edu/~jurafsky/slp3/)
- [演算法導論](https://mitpress.mit.edu/books/introduction-algorithms)
- [macOS 輸入法開發指南](https://developer.apple.com/documentation/inputmethodkit)

## 版本更新日誌

### v0.1.0 (當前)
- ✅ 完整的專案架構
- ✅ 核心演算法實現
- ✅ 完整文檔
- ✅ 測試和示範程式

### 下一版本計劃
- [ ] UI 界面
- [ ] 完整詞典
- [ ] 性能優化
- [ ] 深度學習模型

---

**最後更新**: 2024
**維護者**: Your Name
**授權**: MIT License

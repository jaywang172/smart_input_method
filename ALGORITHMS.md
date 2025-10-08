# 演算法詳解

本文檔詳細說明輸入法中使用的各種演算法和資料結構。

## 1. Trie 樹（前綴樹）

### 1.1 基本概念

Trie 是一種樹狀資料結構，用於高效地存儲和檢索字串集合。

**特點**:
- 根節點不包含字符
- 從根節點到某一節點的路徑上的字符連接起來，為該節點對應的字串
- 每個節點的所有子節點包含的字符都不相同

### 1.2 操作複雜度

| 操作 | 時間複雜度 | 空間複雜度 |
|------|-----------|-----------|
| 插入 | O(m) | O(m) |
| 查找 | O(m) | O(1) |
| 前綴查找 | O(p + n) | O(n) |

其中 m 是字串長度，p 是前綴長度，n 是匹配的字串數量。

### 1.3 應用場景

1. **自動補全**: 輸入前綴，返回所有可能的完整詞
2. **詞頻統計**: 在節點中存儲出現次數
3. **拼寫檢查**: 快速判斷單詞是否存在

### 1.4 優化技巧

```swift
// 優化1: 使用字典而非固定大小陣列
var children: [Character: TrieNode] = [:]  // 節省空間

// 優化2: 只在終止節點存儲完整字串
var word: String?  // 只在 isEndOfWord = true 時有值

// 優化3: 存儲頻率用於排序
var frequency: Int = 0
```

## 2. N-gram 語言模型

### 2.1 基本概念

N-gram 是一種統計語言模型，基於前 n-1 個詞預測第 n 個詞。

**類型**:
- Unigram (1-gram): P(w)
- Bigram (2-gram): P(w₂|w₁)
- Trigram (3-gram): P(w₃|w₁,w₂)

### 2.2 機率計算

#### 極大似然估計 (MLE)

```
P(wₙ|wₙ₋₁) = Count(wₙ₋₁, wₙ) / Count(wₙ₋₁)
```

**問題**: 零機率問題（訓練集中未出現的詞組合）

#### Laplace 平滑

```
P(wₙ|wₙ₋₁) = (Count(wₙ₋₁, wₙ) + α) / (Count(wₙ₋₁) + α × V)
```

其中:
- α: 平滑參數（通常為 1）
- V: 詞彙表大小

### 2.3 句子機率

使用鏈式法則：

```
P(w₁, w₂, ..., wₙ) = P(w₁) × P(w₂|w₁) × P(w₃|w₁,w₂) × ... × P(wₙ|wₙ₋₁)
```

實際計算中使用對數避免下溢：

```
log P(sentence) = log P(w₁) + log P(w₂|w₁) + ... + log P(wₙ|wₙ₋₁)
```

### 2.4 應用

1. **候選詞排序**: 根據上下文機率排序
2. **句子生成**: 逐詞生成最可能的句子
3. **語言檢測**: 比較不同語言模型的機率

## 3. Viterbi 演算法

### 3.1 問題定義

給定:
- 觀察序列: O = [o₁, o₂, ..., oₙ]（注音符號）
- 狀態集合: S = {s₁, s₂, ..., sₘ}（可能的中文字）
- 轉移機率: P(sⱼ|sᵢ)（從字 sᵢ 到字 sⱼ 的機率）
- 發射機率: P(oₖ|sᵢ)（字 sᵢ 對應注音 oₖ 的機率）

求: 最可能的狀態序列 S* = [s₁*, s₂*, ..., sₙ*]

### 3.2 演算法流程

```
1. 初始化
   δ₁(i) = π(i) × P(o₁|sᵢ)  // π(i) 是初始狀態機率
   ψ₁(i) = 0

2. 遞迴
   for t = 2 to n:
       for each state j:
           δₜ(j) = max_i [δₜ₋₁(i) × P(sⱼ|sᵢ)] × P(oₜ|sⱼ)
           ψₜ(j) = argmax_i [δₜ₋₁(i) × P(sⱼ|sᵢ)]

3. 終止
   P* = max_i δₙ(i)
   sₙ* = argmax_i δₙ(i)

4. 回溯
   for t = n-1 to 1:
       sₜ* = ψₜ₊₁(sₜ₊₁*)
```

### 3.3 複雜度分析

- 時間複雜度: O(n × m²)
  - n: 序列長度
  - m: 每個位置的狀態數
  
- 空間複雜度: O(n × m)

### 3.4 優化策略

```swift
// 優化1: Beam Search - 只保留 top-k 狀態
let beamWidth = 5
states.sort { $0.probability > $1.probability }
states = Array(states.prefix(beamWidth))

// 優化2: 使用對數機率避免下溢
let logProb = log(prevProb) + log(transProb) + log(emitProb)

// 優化3: 提前剪枝
if probability < threshold {
    continue
}
```

## 4. 動態規劃 - 注音分段

### 4.1 問題描述

給定注音字串，找出最佳的分段方式，使得每段都能轉換為有效的中文字。

例如: "ㄋㄧˇㄏㄠˇ" → "ㄋㄧˇ" + "ㄏㄠˇ" → "你" + "好"

### 4.2 狀態定義

```
dp[i] = 前 i 個字符的最佳轉換結果列表
```

### 4.3 轉移方程

```
for i = 1 to n:
    for j = 0 to i-1:
        segment = input[j:i]
        if segment 可以轉換:
            for each 轉換結果 candidate:
                for each dp[j] 中的結果 prev:
                    score = prev.score × P(candidate)
                    dp[i].append((word: candidate, score: score, path: prev.path + [candidate]))
```

### 4.4 複雜度

- 時間複雜度: O(n² × k × m)
  - n: 字串長度
  - k: 平均候選數
  - m: dp[j] 中的結果數
  
- 空間複雜度: O(n × m)

### 4.5 剪枝優化

```swift
// 只保留分數最高的 top-k 個結果
dp[i].sort { $0.score > $1.score }
if dp[i].count > 10 {
    dp[i] = Array(dp[i].prefix(10))
}
```

## 5. 特徵工程（語言檢測）

### 5.1 特徵類型

#### 字符級特徵

1. **注音符號比例**
   ```
   ratio = count(bopomofo_chars) / total_chars
   ```

2. **ASCII 字母比例**
   ```
   ratio = count(ascii_letters) / total_chars
   ```

3. **中文字符比例**
   ```
   ratio = count(chinese_chars) / total_chars
   ```

#### 詞級特徵

4. **英文單詞匹配度**
   ```
   match_score = count(matched_words) / total_words
   ```

#### 上下文特徵

5. **前文語言**
   ```
   context_score = detect_language(context)
   ```

#### 統計特徵

6. **平均字符長度（bytes）**
   ```
   avg_length = total_bytes / char_count
   ```
   - 中文字符通常 3 bytes (UTF-8)
   - 英文字符通常 1 byte

### 5.2 特徵組合

使用加權求和：

```
chinese_score = w₁ × bopomofo_ratio 
              + w₂ × chinese_ratio 
              + w₃ × context_score

english_score = w₄ × ascii_ratio 
              + w₅ × word_match 
              + w₆ × (1 - context_score)
```

權重可以通過訓練數據學習得到。

## 6. 樸素貝葉斯分類器

### 6.1 貝葉斯定理

```
P(Language|Features) = P(Features|Language) × P(Language) / P(Features)
```

### 6.2 樸素貝葉斯假設

假設特徵之間相互獨立：

```
P(Features|Language) = ∏ P(Featureᵢ|Language)
```

### 6.3 分類決策

```
Language* = argmax_L P(L) × ∏ P(Fᵢ|L)
```

實際計算中使用對數：

```
log P(L|F) = log P(L) + ∑ log P(Fᵢ|L)
```

### 6.4 訓練過程

```swift
// 計算先驗機率
P(Language) = count(Language) / total_samples

// 計算條件機率（使用平均值）
for each feature:
    for each language:
        P(feature|language) = average(feature_values_for_language)
```

### 6.5 增量學習

```swift
// 使用學習率更新權重
learning_rate = 0.1

if prediction == correct_label:
    weight += learning_rate × (feature_value - weight)
else:
    weight -= learning_rate × (feature_value - weight)
```

## 7. 性能優化總結

### 7.1 時間優化

1. **哈希表**: O(1) 查找
2. **剪枝**: 減少搜索空間
3. **緩存**: 避免重複計算
4. **批處理**: 減少函數調用開銷

### 7.2 空間優化

1. **字典代替陣列**: 稀疏數據
2. **只存儲必要資訊**: 減少冗餘
3. **壓縮技術**: 大型詞典壓縮
4. **延遲加載**: 按需載入資源

### 7.3 準確度優化

1. **集成學習**: 組合多個模型
2. **特徵選擇**: 選擇最有效的特徵
3. **正則化**: 防止過擬合
4. **交叉驗證**: 評估模型泛化能力

## 參考文獻

1. Jurafsky, D., & Martin, J. H. (2023). Speech and Language Processing (3rd ed.)
2. Cormen, T. H., et al. (2009). Introduction to Algorithms (3rd ed.)
3. Manning, C. D., & Schütze, H. (1999). Foundations of Statistical Natural Language Processing

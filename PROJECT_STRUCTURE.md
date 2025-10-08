# 智能混合輸入法專案結構

```
輸入法/
│
├── README.md                      # 專案概述和快速開始
├── ARCHITECTURE.md                # 架構設計文檔
├── ALGORITHMS.md                  # 演算法詳解
├── USAGE_GUIDE.md                 # 使用指南
├── PROJECT_STRUCTURE.md           # 本檔案
│
├── Core/                          # 核心引擎模組
│   ├── InputEngine.swift          # 主輸入引擎
│   │   - 整合所有組件
│   │   - 管理輸入緩衝和上下文
│   │   - 候選詞生成和排序
│   │   - 使用者互動處理
│   │
│   ├── BopomofoConverter.swift    # 注音轉中文轉換器
│   │   - 注音到中文映射
│   │   - Viterbi 演算法實現
│   │   - 動態規劃分段
│   │   - 上下文感知轉換
│   │
│   └── LanguageDetector.swift     # 語言檢測器
│       - 特徵提取
│       - 語言分類
│       - 上下文分析
│       - 使用者歷史學習
│
├── DataStructures/                # 資料結構模組
│   ├── Trie.swift                 # Trie 樹實現
│   │   - 快速詞彙查找
│   │   - 前綴匹配
│   │   - 自動補全
│   │   - 頻率排序
│   │
│   └── NgramModel.swift           # N-gram 語言模型
│       - Unigram/Bigram/Trigram
│       - 機率計算
│       - Laplace 平滑
│       - 上下文預測
│       - 模型持久化
│
├── ML/                            # 機器學習模組
│   ├── LanguageClassifier.swift  # 語言分類器
│   │   - 樸素貝葉斯分類
│   │   - 特徵工程
│   │   - 批量訓練
│   │   - 增量學習
│   │   - 模型保存/加載
│   │
│   └── ContextPredictor.swift     # 上下文預測器 (待實現)
│       - 基於 LSTM 的預測
│       - 深度學習模型
│       - 序列到序列學習
│
├── UI/                            # 使用者界面模組 (待實現)
│   ├── CandidateView.swift        # 候選詞視圖
│   │   - 候選詞列表顯示
│   │   - 選擇互動
│   │   - 鍵盤快捷鍵
│   │
│   └── InputPanel.swift           # 輸入面板
│       - 輸入顯示
│       - 組字區
│       - 狀態指示
│
├── Resources/                     # 資源檔案
│   ├── dictionaries/              # 詞典資料
│   │   ├── chinese_dict.txt       # 中文詞典
│   │   ├── english_dict.txt       # 英文詞典
│   │   ├── bopomofo_map.txt       # 注音映射表
│   │   └── user_dict.txt          # 使用者自定義詞典
│   │
│   └── models/                    # 機器學習模型
│       ├── ngram_model.json       # N-gram 模型
│       ├── classifier.json        # 語言分類器
│       └── context_predictor.mlmodel  # 上下文預測模型
│
└── Tests/                         # 測試模組
    ├── UnitTests.swift            # 單元測試
    │   - Trie 測試
    │   - N-gram 測試
    │   - 語言檢測測試
    │   - 轉換器測試
    │
    ├── IMEDemo.swift              # 示範程式
    │   - 互動式演示
    │   - 功能展示
    │   - 性能測試
    │
    └── PerformanceTests.swift     # 性能測試 (待實現)
        - 響應時間測試
        - 記憶體使用測試
        - 並發測試
```

## 模組依賴關係

```
InputEngine (核心)
    ├── LanguageDetector
    ├── BopomofoConverter
    │   ├── NgramModel
    │   └── Trie
    ├── NgramModel
    ├── Trie (中文)
    └── Trie (英文)

BopomofoConverter
    ├── NgramModel
    └── Trie

LanguageDetector
    └── (獨立模組)

LanguageClassifier (ML)
    └── (獨立模組)
```

## 數據流

```
使用者輸入
    ↓
InputEngine.handleInput()
    ↓
LanguageDetector.detect() → 判斷語言
    ↓
├─→ 中文路徑
│   ├── BopomofoConverter.convert() → 注音轉中文
│   │   ├── 查找注音映射表
│   │   ├── Viterbi 演算法找最佳路徑
│   │   └── NgramModel 計算機率
│   └── Trie.getAllWordsWithPrefix() → 前綴匹配
│
└─→ 英文路徑
    └── Trie.getAllWordsWithPrefix() → 自動補全
    ↓
候選詞排序
    ↓
返回候選詞列表
```

## 檔案說明

### 核心檔案

| 檔案 | 行數 | 主要功能 |
|------|------|----------|
| InputEngine.swift | ~250 | 主引擎邏輯 |
| BopomofoConverter.swift | ~280 | 注音轉換 |
| LanguageDetector.swift | ~300 | 語言檢測 |
| Trie.swift | ~150 | Trie 資料結構 |
| NgramModel.swift | ~250 | N-gram 模型 |
| LanguageClassifier.swift | ~350 | ML 分類器 |

### 測試檔案

| 檔案 | 行數 | 主要功能 |
|------|------|----------|
| UnitTests.swift | ~300 | 單元測試 |
| IMEDemo.swift | ~250 | 演示程式 |

### 文檔檔案

| 檔案 | 用途 |
|------|------|
| README.md | 專案概述 |
| ARCHITECTURE.md | 架構設計 |
| ALGORITHMS.md | 演算法說明 |
| USAGE_GUIDE.md | 使用教學 |
| PROJECT_STRUCTURE.md | 專案結構 |

## 待實現功能

### 優先級 1 (核心功能)
- [ ] 完整的注音到中文映射表
- [ ] 大型中文詞典
- [ ] 大型英文詞典
- [ ] 完善的 N-gram 訓練語料

### 優先級 2 (UI)
- [ ] 候選詞視圖實現
- [ ] 輸入面板實現
- [ ] 鍵盤事件處理
- [ ] macOS 輸入法擴展整合

### 優先級 3 (進階功能)
- [ ] 深度學習上下文預測器
- [ ] 使用者個性化學習
- [ ] 雲端詞典同步
- [ ] 拼寫檢查和糾錯

### 優先級 4 (優化)
- [ ] 性能優化
- [ ] 記憶體優化
- [ ] 並發處理
- [ ] 緩存機制

## 開發指南

### 添加新功能

1. 在相應模組創建新檔案
2. 遵循現有的程式碼風格
3. 添加適當的註釋和文檔
4. 編寫單元測試
5. 更新相關文檔

### 程式碼風格

- 使用 Swift 命名規範
- 函數名使用駝峰命名法
- 添加適當的訪問控制
- 使用 MARK 註釋分組程式碼
- 添加函數和類的文檔註釋

### 測試要求

- 所有新功能必須有單元測試
- 測試覆蓋率至少 80%
- 包含邊界情況測試
- 性能關鍵路徑要有基準測試

## 版本歷史

### v0.1.0 (當前版本)
- ✅ 基礎專案架構
- ✅ Trie 資料結構實現
- ✅ N-gram 模型實現
- ✅ 語言檢測器實現
- ✅ 注音轉換器實現
- ✅ 語言分類器實現
- ✅ 主輸入引擎實現
- ✅ 單元測試框架
- ✅ 演示程式
- ✅ 完整文檔

### v0.2.0 (計劃中)
- [ ] UI 組件實現
- [ ] macOS 輸入法整合
- [ ] 完整詞典數據
- [ ] 性能優化

### v1.0.0 (長期目標)
- [ ] 深度學習模型
- [ ] 個性化學習
- [ ] 雲端同步
- [ ] 多語言支援

## 貢獻指南

歡迎貢獻！請遵循以下步驟：

1. Fork 專案
2. 創建功能分支
3. 提交變更
4. 推送到分支
5. 創建 Pull Request

## 授權

MIT License

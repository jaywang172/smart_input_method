# 🎯 智能輸入法 (Smart Input Method)

**忘記切換也能打中文！**

一個智能的 macOS 輸入法，能夠自動識別你是在輸入中文（注音）還是英文，無需手動切換輸入模式。

## ✨ 核心功能

- **🔍 智能檢測**：自動判斷輸入是注音還是英文
- **⌨️ 無需切換**：統一使用英文鍵盤，自動輸出正確結果
- **🇹🇼 注音轉中文**：英文鍵盤輸入 → 注音符號 → 中文字
- **🔤 英文保留**：英文單字自動保持不變
- **⚡ 高效能**：輸入延遲 < 50ms，內存使用 < 100MB

## 📊 效能基準測試 (Benchmarks)

- **詞典規模**：10,000 entries (性能測試基準)
- **候選生成平均延遲**：< 1 ms (單詞查找約 0.0003 ms)
- **測試案例**：63 cases (核心模組單元測試)

## 🎮 使用演示

```
輸入: su3cl3
  ↓ 自動檢測為注音
輸出: 你好

輸入: hello
  ↓ 自動檢測為英文
輸出: hello

輸入: rup wu0 wu0 fu45p cl3
  ↓ 自動檢測為注音
輸出: 今天天氣真好
```

## 📚 快速導航

**新來的？從這裡開始：**
- 📋 [快速開始指南](QUICK_START.md) - 今天就開始！
- 📊 [執行摘要](EXECUTIVE_SUMMARY.md) - 專案概覽和上架計劃
- 🔍 [Code Review](CODE_REVIEW.md) - Linus 式代碼審查
- 🚀 [App Store 路線圖](APP_STORE_ROADMAP.md) - 詳細上架步驟

**開發者文檔：**
- 🏗️ [專案架構](ARCHITECTURE.md)
- 🧮 [演算法說明](ALGORITHMS.md)
- 📖 [使用指南](USAGE_GUIDE.md)
- 🔧 [專案結構](PROJECT_STRUCTURE.md)

## 系統架構

```
SmartIME/
├── Core/                    # 核心引擎
│   ├── InputEngine.swift    # 輸入引擎主邏輯
│   ├── LanguageDetector.swift  # 語言檢測器
│   └── BopomofoConverter.swift # 注音轉換器
├── DataStructures/          # 資料結構
│   ├── Trie.swift          # Trie 樹實現
│   ├── NgramModel.swift    # N-gram 語言模型
│   └── DictionaryLoader.swift  # 詞典加載器
├── ML/                      # 機器學習模組
│   ├── LanguageClassifier.swift  # 語言分類器
│   └── ContextPredictor.swift    # 上下文預測器
├── UI/                      # 使用者界面
│   ├── CandidateView.swift # 候選詞視圖
│   └── InputPanel.swift    # 輸入面板
├── Resources/               # 資源檔案
│   ├── dictionaries/       # 詞典資料
│   └── models/             # ML 模型
└── Tests/                   # 測試檔案
```

## 核心演算法

### 1. Trie 樹（前綴樹）
用於快速詞彙查找和自動補全，時間複雜度 O(m)，m 為詞長度。

### 2. N-gram 語言模型
基於統計的語言模型，用於預測下一個詞的機率：
- Unigram: P(w)
- Bigram: P(w|w-1)
- Trigram: P(w|w-1,w-2)

### 3. 維特比演算法（Viterbi Algorithm）
用於找出最佳的注音到中文轉換路徑。

### 4. 機器學習分類器
使用特徵工程和分類模型判斷輸入語言：
- 輸入字符類型
- 上下文語言
- 使用者歷史偏好

## 技術需求

- Swift 5.9+
- macOS 12.0+ / Xcode 14.0+（`SmartIMEApp` 輸入法目標）
- Windows 10/11 + Swift Toolchain（`SmartIMECore` / `SmartIMEDemo`）

## 安裝與使用

詳細的安裝和使用說明請參考文檔。

### 以 Swift Package Manager 安裝

1) 在 Xcode 中 File > Add Packages...

2) 輸入本倉庫 URL，新增 `SmartIMECore` 目標。

3) 引入並初始化：

```swift
import SmartIMECore

let engine = InputEngine(config: InputEngineConfig(
    lazyLoadResources: true,
    maxCandidates: 10,
    enableAsync: true,
    resourcePaths: [
        "resource_manifest": "/abs/path/manifest.json"
    ]
))
```

### Windows 快速驗證（核心引擎）

```bash
swift build
swift run SmartIMECoreTests
swift run SmartIMEDemo
```

> 註：`SmartIMEApp`（InputMethodKit）為 macOS 專用目標，Windows 上不會建置該目標。

### 釋出說明（MVP 0.1.0 摘要）

- `InputEngineConfig` 設定式初始化（向後相容）
- 外部化資源（`resource_manifest` 版本管理與回滾）
- `RadixTrie` 壓縮前綴樹 + LRU 快取
- N-gram 改為 log 域 + 絕對折扣平滑
- 注音 beam search 後備路徑（log 域 + 上下文）
- 非阻塞候選介面、用戶詞庫學習、觀測抽樣

## 開發路線圖

- [x] 專案架構設計
- [ ] 核心資料結構實現
- [ ] 注音轉中文引擎
- [ ] 語言檢測模型
- [ ] UI 界面開發
- [ ] 性能優化
- [ ] 測試與部署

## 貢獻

歡迎提交 Issue 和 Pull Request！

## 授權

MIT License

## SDK 版本策略與初始化

- 版本採用語義化版本（SemVer）。Minor/Patch 僅新增後向相容能力或修正；不破壞現有 API 行為（never break userspace）。
- 新增 `InputEngineConfig`，舊有 `InputEngine()` 仍可使用，預設行為不變。

初始化範例：

```swift
// 舊用法（保留）
let engine = InputEngine()

// 新用法（可選設定）
let engine2 = InputEngine(config: InputEngineConfig(
    lazyLoadResources: true,
    maxCandidates: 10,
    enableAsync: false,
    resourcePaths: [
        // 可用鍵名："chinese_dictionary", "english_dictionary", "bopomofo_dictionary", "ngram_model", "user_dict"
        "user_dict": "/path/to/user_dict.json",
        // 可使用 resource_manifest 統一指定資源版本
        "resource_manifest": "/path/to/manifest.json"
    ]
))

// 非阻塞介面（可選）
engine2.handleInputAsync("a") { candidates in
    print(candidates.map { $0.text })
}
```

# 🚀 App Store 上架路線圖

**專案**: macOS 智能輸入法  
**目標**: 上架 Mac App Store  
**預估時間**: 2-3 週

---

## 📋 目錄

1. [階段 1: 代碼清理與重構](#階段-1-代碼清理與重構)
2. [階段 2: 核心功能整合](#階段-2-核心功能整合)
3. [階段 3: App 打包與配置](#階段-3-app-打包與配置)
4. [階段 4: 測試與優化](#階段-4-測試與優化)
5. [階段 5: App Store 提交](#階段-5-app-store-提交)
6. [階段 6: 審核與上線](#階段-6-審核與上線)

---

## 階段 1: 代碼清理與重構

**時間**: 1-2 天  
**優先級**: 🔴 P0 - 必須完成

### 1.1 清理測試文件

**目標**: 刪除所有無用的測試文件

```bash
# 需要刪除的文件（macOS/ 目錄）
rm macOS/correct_smart_input.swift
rm macOS/demo_smart_input.swift
rm macOS/dual_mode_demo.swift
rm macOS/final_correct_input.swift
rm macOS/final_smart_input.swift
rm macOS/interactive_demo.swift
rm macOS/interactive_input_test.swift
rm macOS/interactive_test.swift
rm macOS/perfect_smart_input.swift
rm macOS/quick_test.swift
rm macOS/real_smart_input.swift
rm macOS/simple_demo.swift
rm macOS/simple_smart_output.swift
rm macOS/smart_input_test.swift
rm macOS/smart_output_demo.swift
rm macOS/stable_test.swift
rm macOS/test_demo.swift
rm macOS/test_input_method.swift
rm macOS/ultimate_smart_input.swift

# 保留
✅ macOS/truly_smart_input.swift  # 作為參考實現
```

**檢查清單**:
- [ ] 刪除 18 個無用測試文件
- [ ] 保留 `truly_smart_input.swift` 作為參考
- [ ] 清理 `build/` 目錄
- [ ] 更新 `.gitignore`

---

### 1.2 清理根目錄測試文件

```bash
# 需要刪除的文件（根目錄）
rm debug_test.swift
rm ime_demo_main.swift
rm run_ime_demo.swift
rm simple_test.swift
rm test_advanced.swift
rm test_interactive.swift
rm test_keyboard_simulation.swift
rm test_manual.swift
rm test_simple.swift
rm test_stress.swift
rm test_typing_scenario.swift

# 清理腳本
rm run_demo.sh
rm run_demo_fixed.sh
rm run_tests.sh
rm quick_test.sh
```

**檢查清單**:
- [ ] 刪除所有根目錄測試文件
- [ ] 刪除所有測試腳本
- [ ] 保留 `build.sh`（主編譯腳本）

---

### 1.3 整理目錄結構

**目標結構**:
```
輸入法/
├── Core/                          # 核心邏輯
│   ├── KeyboardMapper.swift       # 新增：鍵盤映射
│   ├── SmartInputEngine.swift     # 新增：智能引擎
│   ├── BopomofoConverter.swift    # 重構
│   ├── InputEngine.swift          # 保留
│   └── ...
├── DataStructures/                # 數據結構
├── ML/                            # 機器學習（可選）
├── Resources/                     # 資源文件
│   ├── dictionaries/
│   │   ├── keyboard_mapping.json  # 新增
│   │   └── bopomofo_dict.json     # 新增
│   └── models/
├── macOS/                         # macOS 應用
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── InputMethodController.swift
│   ├── InputMethodServer.swift
│   ├── CandidateWindow.swift
│   ├── Info.plist
│   ├── build.sh
│   └── truly_smart_input.swift    # 參考實現
├── Tests/                         # 單元測試
│   ├── KeyboardMapperTests.swift  # 新增
│   ├── SmartInputEngineTests.swift # 新增
│   └── ...
├── README.md
├── CODE_REVIEW.md
└── APP_STORE_ROADMAP.md
```

**檢查清單**:
- [ ] 創建新的核心文件
- [ ] 移動資源文件
- [ ] 更新文檔

---

## 階段 2: 核心功能整合

**時間**: 2-3 天  
**優先級**: 🔴 P0 - 必須完成

### 2.1 創建 KeyboardMapper

**文件**: `Core/KeyboardMapper.swift`

**功能**:
- 英文鍵盤 → 注音符號映射
- 從 JSON 文件加載映射表
- 快速查詢

**實現**:
```swift
import Foundation

/// 鍵盤映射器：英文鍵盤 → 注音符號
class KeyboardMapper {
    
    private var mapping: [Character: String] = [:]
    
    init() {
        loadMapping()
    }
    
    /// 從 JSON 文件加載映射表
    private func loadMapping() {
        // 從 Resources/dictionaries/keyboard_mapping.json 加載
    }
    
    /// 轉換英文鍵盤輸入為注音序列
    func convert(_ input: String) -> String {
        var result = ""
        for char in input {
            if let bopomofo = mapping[char] {
                result += bopomofo
            } else {
                result += String(char)
            }
        }
        return result
    }
}
```

**檢查清單**:
- [ ] 創建 `KeyboardMapper.swift`
- [ ] 創建 `keyboard_mapping.json`
- [ ] 添加單元測試
- [ ] 驗證映射正確性

---

### 2.2 創建 SmartInputEngine

**文件**: `Core/SmartInputEngine.swift`

**功能**:
- 智能檢測輸入類型（注音 vs 英文）
- 自動轉換輸出
- 候選詞生成

**實現**:
```swift
import Foundation

/// 智能輸入引擎
class SmartInputEngine {
    
    private let keyboardMapper: KeyboardMapper
    private let bopomofoConverter: BopomofoConverter
    private let dictionaryLookup: DictionaryLookup
    
    init(keyboardMapper: KeyboardMapper,
         bopomofoConverter: BopomofoConverter,
         dictionaryLookup: DictionaryLookup) {
        self.keyboardMapper = keyboardMapper
        self.bopomofoConverter = bopomofoConverter
        self.dictionaryLookup = dictionaryLookup
    }
    
    /// 處理輸入
    func processInput(_ input: String) -> InputResult {
        // 1. 轉換為注音序列
        let bopomofoSequence = keyboardMapper.convert(input)
        
        // 2. 檢查是否為有效注音
        if let candidates = dictionaryLookup.lookup(bopomofoSequence) {
            return InputResult(
                output: candidates.first ?? input,
                type: .bopomofo,
                candidates: candidates,
                bopomofoSequence: bopomofoSequence
            )
        }
        
        // 3. 保持英文
        return InputResult(
            output: input,
            type: .english,
            candidates: [input],
            bopomofoSequence: bopomofoSequence
        )
    }
}

struct InputResult {
    let output: String
    let type: InputType
    let candidates: [String]
    let bopomofoSequence: String
    
    enum InputType {
        case bopomofo
        case english
    }
}
```

**檢查清單**:
- [ ] 創建 `SmartInputEngine.swift`
- [ ] 整合 `truly_smart_input.swift` 邏輯
- [ ] 添加單元測試
- [ ] 驗證功能正確性

---

### 2.3 創建 DictionaryLookup

**文件**: `Core/DictionaryLookup.swift`

**功能**:
- 注音序列查詢
- 分詞算法
- 候選詞排序

**實現**:
```swift
import Foundation

/// 字典查詢器
class DictionaryLookup {
    
    private var dictionary: [String: [String]] = [:]
    
    init() {
        loadDictionary()
    }
    
    /// 從 JSON 文件加載字典
    private func loadDictionary() {
        // 從 Resources/dictionaries/bopomofo_dict.json 加載
    }
    
    /// 查詢注音序列
    func lookup(_ bopomofoSequence: String) -> [String]? {
        // 1. 直接查找
        if let candidates = dictionary[bopomofoSequence] {
            return candidates
        }
        
        // 2. 分詞查找
        if let segmented = segment(bopomofoSequence) {
            return segmented
        }
        
        return nil
    }
    
    /// 分詞算法
    private func segment(_ sequence: String) -> [String]? {
        // 實現分詞邏輯
    }
}
```

**檢查清單**:
- [ ] 創建 `DictionaryLookup.swift`
- [ ] 創建 `bopomofo_dict.json`
- [ ] 實現分詞算法
- [ ] 添加單元測試

---

### 2.4 重構 BopomofoConverter

**目標**: 整合新的邏輯

**修改**:
```swift
class BopomofoConverter {
    
    private let keyboardMapper: KeyboardMapper
    private let dictionaryLookup: DictionaryLookup
    
    init(keyboardMapper: KeyboardMapper, dictionaryLookup: DictionaryLookup) {
        self.keyboardMapper = keyboardMapper
        self.dictionaryLookup = dictionaryLookup
    }
    
    // 保留舊的 API（向後兼容）
    func convert(_ bopomofo: String) -> [(word: String, score: Double)] {
        // ...
    }
    
    // 新增：智能轉換
    func smartConvert(_ input: String) -> [(word: String, score: Double)] {
        let bopomofo = keyboardMapper.convert(input)
        if let candidates = dictionaryLookup.lookup(bopomofo) {
            return candidates.map { (word: $0, score: 1.0) }
        }
        return [(word: input, score: 1.0)]
    }
}
```

**檢查清單**:
- [ ] 添加 `smartConvert` 方法
- [ ] 保持向後兼容
- [ ] 更新單元測試

---

## 階段 3: App 打包與配置

**時間**: 1-2 天  
**優先級**: 🔴 P0 - 必須完成

### 3.1 配置 Info.plist

**文件**: `macOS/Info.plist`

**必需配置**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 基本信息 -->
    <key>CFBundleName</key>
    <string>智能輸入法</string>
    
    <key>CFBundleDisplayName</key>
    <string>智能輸入法</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.SmartInputMethod</string>
    
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    
    <!-- 輸入法配置 -->
    <key>InputMethodConnectionName</key>
    <string>SmartInputMethod_Connection</string>
    
    <key>InputMethodServerControllerClass</key>
    <string>InputMethodServer</string>
    
    <key>tsInputMethodCharacterRepertoireKey</key>
    <array>
        <string>Hant</string>
        <string>Hans</string>
    </array>
    
    <!-- 最低系統要求 -->
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    
    <!-- 圖標 -->
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    
    <!-- 隱私權限 -->
    <key>NSAppleEventsUsageDescription</key>
    <string>智能輸入法需要訪問鍵盤輸入以提供智能轉換功能。</string>
</dict>
</plist>
```

**檢查清單**:
- [ ] 更新 Bundle Identifier（使用你的開發者 ID）
- [ ] 設置版本號
- [ ] 配置輸入法參數
- [ ] 添加隱私權限說明

---

### 3.2 創建 App 圖標

**要求**:
- 尺寸: 1024x1024 px
- 格式: PNG（無透明度）
- 設計: 簡潔、專業、易識別

**建議設計**:
```
圖標元素：
- 主色調：藍色/綠色（科技感）
- 圖案：鍵盤 + 中文字符
- 風格：扁平化、現代
```

**工具**:
- Sketch / Figma（設計）
- Icon Generator（生成多尺寸）

**檢查清單**:
- [ ] 設計 1024x1024 圖標
- [ ] 生成所有尺寸（16, 32, 64, 128, 256, 512, 1024）
- [ ] 添加到 `macOS/Assets.xcassets/`

---

### 3.3 配置簽名與公證

**要求**:
- Apple Developer Account（$99/年）
- Developer ID Application Certificate
- App-Specific Password（用於公證）

**步驟**:

1. **創建 Certificate**:
   ```bash
   # 在 Keychain Access 中請求證書
   # 類型：Developer ID Application
   ```

2. **簽名 App**:
   ```bash
   codesign --deep --force --verify --verbose \
       --sign "Developer ID Application: Your Name (TEAM_ID)" \
       --options runtime \
       SmartInputMethod.app
   ```

3. **公證 App**:
   ```bash
   # 創建 DMG
   hdiutil create -volname "智能輸入法" -srcfolder SmartInputMethod.app -ov -format UDZO SmartInputMethod.dmg
   
   # 上傳公證
   xcrun notarytool submit SmartInputMethod.dmg \
       --apple-id "your@email.com" \
       --password "app-specific-password" \
       --team-id "TEAM_ID" \
       --wait
   
   # 裝訂公證票據
   xcrun stapler staple SmartInputMethod.app
   ```

**檢查清單**:
- [ ] 註冊 Apple Developer Account
- [ ] 創建 Developer ID Certificate
- [ ] 簽名 App
- [ ] 公證 App
- [ ] 驗證簽名和公證

---

### 3.4 創建安裝器

**選項 1: DMG（推薦）**

```bash
# 創建 DMG
hdiutil create -volname "智能輸入法" \
    -srcfolder SmartInputMethod.app \
    -ov -format UDZO \
    SmartInputMethod.dmg

# 自定義 DMG 外觀
# 1. 掛載 DMG
# 2. 添加背景圖片
# 3. 設置圖標位置
# 4. 創建「應用程式」快捷方式
```

**選項 2: PKG**

```bash
# 使用 pkgbuild
pkgbuild --root SmartInputMethod.app \
    --identifier com.yourcompany.SmartInputMethod \
    --version 1.0.0 \
    --install-location /Library/Input\ Methods \
    SmartInputMethod.pkg
```

**檢查清單**:
- [ ] 創建 DMG 或 PKG
- [ ] 自定義安裝器外觀
- [ ] 添加 README
- [ ] 測試安裝流程

---

## 階段 4: 測試與優化

**時間**: 2-3 天  
**優先級**: 🟡 P1 - 應該完成

### 4.1 單元測試

**測試覆蓋率目標**: 80%+

**測試文件**:
```swift
// Tests/KeyboardMapperTests.swift
class KeyboardMapperTests: XCTestCase {
    func testBasicMapping() {
        let mapper = KeyboardMapper()
        XCTAssertEqual(mapper.convert("su3cl3"), "ㄋㄧˇㄏㄠˇ")
    }
}

// Tests/SmartInputEngineTests.swift
class SmartInputEngineTests: XCTestCase {
    func testBopomofoInput() {
        let engine = SmartInputEngine()
        let result = engine.processInput("su3cl3")
        XCTAssertEqual(result.output, "你好")
        XCTAssertEqual(result.type, .bopomofo)
    }
    
    func testEnglishInput() {
        let engine = SmartInputEngine()
        let result = engine.processInput("hello")
        XCTAssertEqual(result.output, "hello")
        XCTAssertEqual(result.type, .english)
    }
}
```

**檢查清單**:
- [ ] 編寫單元測試
- [ ] 運行測試（`swift test`）
- [ ] 達到 80% 覆蓋率
- [ ] 修復所有失敗的測試

---

### 4.2 集成測試

**測試場景**:

1. **基本輸入**:
   - 輸入 `su3cl3` → 輸出 `你好`
   - 輸入 `hello` → 輸出 `hello`

2. **長句子**:
   - 輸入 `rup wu0 wu0 fu45p cl3` → 輸出 `今天天氣真好`

3. **混合輸入**:
   - 輸入 `hello su3cl3` → 輸出 `hello 你好`

4. **邊界情況**:
   - 空輸入
   - 特殊字符
   - 超長輸入

**檢查清單**:
- [ ] 編寫集成測試
- [ ] 測試所有場景
- [ ] 修復 bug

---

### 4.3 性能測試

**性能目標**:
- 輸入延遲 < 50ms
- 候選詞生成 < 100ms
- 內存使用 < 100MB

**測試工具**:
```swift
// Tests/PerformanceTests.swift
class PerformanceTests: XCTestCase {
    func testInputLatency() {
        let engine = SmartInputEngine()
        measure {
            _ = engine.processInput("su3cl3")
        }
    }
}
```

**檢查清單**:
- [ ] 測試輸入延遲
- [ ] 測試內存使用
- [ ] 優化性能瓶頸

---

### 4.4 用戶測試

**測試用戶**: 5-10 人

**測試任務**:
1. 安裝輸入法
2. 輸入中文句子
3. 輸入英文單字
4. 混合輸入
5. 填寫反饋問卷

**檢查清單**:
- [ ] 招募測試用戶
- [ ] 收集反饋
- [ ] 修復問題
- [ ] 優化體驗

---

## 階段 5: App Store 提交

**時間**: 1 天  
**優先級**: 🔴 P0 - 必須完成

### 5.1 準備 App Store 資料

**必需資料**:

1. **App 名稱**:
   - 主要名稱：智能輸入法
   - 副標題：忘記切換也能打中文

2. **App 描述**:
   ```
   智能輸入法 - 忘記切換也能打中文

   你是否經常忘記切換輸入法，打出一串奇怪的英文字母？
   智能輸入法幫你解決這個問題！

   ✨ 核心功能：
   • 自動檢測：智能判斷你是在輸入中文還是英文
   • 無需切換：統一使用英文鍵盤，自動輸出正確結果
   • 注音輸入：支持完整的注音符號輸入
   • 英文保留：英文單字自動保持不變
   • 混合輸入：中英文混合輸入，智能處理

   🎯 使用場景：
   • 忘記切換輸入法時，自動轉換為中文
   • 快速輸入中英文混合內容
   • 提高打字效率，減少切換次數

   📱 系統要求：
   • macOS 11.0 或更高版本

   🔒 隱私保護：
   • 所有處理都在本地完成
   • 不上傳任何輸入內容
   • 不收集用戶數據
   ```

3. **關鍵字**:
   ```
   輸入法,注音,中文,智能,鍵盤,打字,macOS,繁體中文,輸入,轉換
   ```

4. **分類**:
   - 主要分類：工具程式
   - 次要分類：生產力工具

5. **截圖**（至少 3 張）:
   - 尺寸：1280x800 或更高
   - 內容：
     1. 主界面（候選詞窗口）
     2. 智能檢測演示（注音 → 中文）
     3. 英文保留演示
     4. 混合輸入演示
     5. 設置界面（如果有）

6. **預覽視頻**（可選但推薦）:
   - 長度：15-30 秒
   - 內容：展示核心功能

**檢查清單**:
- [ ] 準備 App 名稱和描述
- [ ] 選擇分類和關鍵字
- [ ] 製作截圖（至少 3 張）
- [ ] 製作預覽視頻（可選）

---

### 5.2 提交到 App Store Connect

**步驟**:

1. **登入 App Store Connect**:
   - https://appstoreconnect.apple.com

2. **創建新 App**:
   - 點擊「我的 App」→「+」→「新增 App」
   - 選擇平台：macOS
   - 輸入 App 名稱
   - 選擇語言：繁體中文
   - Bundle ID：com.yourcompany.SmartInputMethod
   - SKU：SmartInputMethod

3. **填寫 App 資訊**:
   - 名稱、副標題、描述
   - 關鍵字
   - 分類
   - 截圖
   - 預覽視頻

4. **上傳 Build**:
   ```bash
   # 使用 Transporter 上傳
   # 或使用 Xcode
   ```

5. **填寫版本資訊**:
   - 版本號：1.0.0
   - 版權：© 2025 Your Company
   - 聯絡資訊

6. **設定定價**:
   - 免費 或 付費（建議先免費）

7. **提交審核**:
   - 點擊「提交審核」

**檢查清單**:
- [ ] 創建 App Store Connect 記錄
- [ ] 填寫所有必需資訊
- [ ] 上傳 Build
- [ ] 提交審核

---

## 階段 6: 審核與上線

**時間**: 1-7 天（Apple 審核時間）  
**優先級**: 🔴 P0 - 必須完成

### 6.1 審核準備

**常見拒絕原因**:

1. **隱私權限說明不清**:
   - 解決：在 Info.plist 中添加詳細說明

2. **功能不完整**:
   - 解決：確保所有功能正常工作

3. **崩潰或 bug**:
   - 解決：充分測試

4. **UI 問題**:
   - 解決：遵循 macOS Human Interface Guidelines

5. **簽名或公證問題**:
   - 解決：確保正確簽名和公證

**檢查清單**:
- [ ] 檢查隱私權限說明
- [ ] 測試所有功能
- [ ] 修復所有已知 bug
- [ ] 檢查 UI 設計
- [ ] 驗證簽名和公證

---

### 6.2 審核期間

**預期時間**: 1-7 天

**狀態追蹤**:
- 等待審核（Waiting for Review）
- 審核中（In Review）
- 待處理（Pending Developer Release）
- 已上架（Ready for Sale）

**如果被拒絕**:
1. 閱讀拒絕原因
2. 修復問題
3. 重新提交

**檢查清單**:
- [ ] 每天檢查審核狀態
- [ ] 及時回應 Apple 的問題
- [ ] 如果被拒絕，快速修復並重新提交

---

### 6.3 上線後

**發布**:
- 審核通過後，App 會自動上架（或手動發布）

**監控**:
- 下載量
- 評分和評論
- 崩潰報告

**更新計劃**:
- 修復 bug
- 添加新功能
- 優化性能

**檢查清單**:
- [ ] 確認 App 已上架
- [ ] 監控下載量和評論
- [ ] 收集用戶反饋
- [ ] 計劃下一個版本

---

## 📊 時間表總覽

| 階段 | 任務 | 時間 | 優先級 |
|------|------|------|--------|
| 1 | 代碼清理與重構 | 1-2 天 | 🔴 P0 |
| 2 | 核心功能整合 | 2-3 天 | 🔴 P0 |
| 3 | App 打包與配置 | 1-2 天 | 🔴 P0 |
| 4 | 測試與優化 | 2-3 天 | 🟡 P1 |
| 5 | App Store 提交 | 1 天 | 🔴 P0 |
| 6 | 審核與上線 | 1-7 天 | 🔴 P0 |
| **總計** | | **8-18 天** | |

---

## 🎯 成功指標

### 技術指標

- [ ] 代碼覆蓋率 > 80%
- [ ] 輸入延遲 < 50ms
- [ ] 內存使用 < 100MB
- [ ] 無崩潰

### 產品指標

- [ ] 通過 App Store 審核
- [ ] 首週下載量 > 100
- [ ] 用戶評分 > 4.0
- [ ] 無嚴重 bug 報告

---

## 📝 檢查清單總覽

### 階段 1: 代碼清理
- [ ] 刪除 18 個測試文件
- [ ] 清理根目錄
- [ ] 整理目錄結構

### 階段 2: 核心功能
- [ ] 創建 KeyboardMapper
- [ ] 創建 SmartInputEngine
- [ ] 創建 DictionaryLookup
- [ ] 重構 BopomofoConverter

### 階段 3: App 打包
- [ ] 配置 Info.plist
- [ ] 創建 App 圖標
- [ ] 簽名和公證
- [ ] 創建安裝器

### 階段 4: 測試
- [ ] 單元測試（80% 覆蓋率）
- [ ] 集成測試
- [ ] 性能測試
- [ ] 用戶測試

### 階段 5: 提交
- [ ] 準備 App Store 資料
- [ ] 提交到 App Store Connect

### 階段 6: 上線
- [ ] 通過審核
- [ ] 監控表現
- [ ] 收集反饋

---

## 🚀 下一步行動

1. **立即開始**: 階段 1 - 代碼清理
2. **閱讀**: `CODE_REVIEW.md` 了解詳細問題
3. **執行**: 按照本路線圖逐步完成

**讓我們開始吧！** 🎉

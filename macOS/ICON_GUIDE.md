# 🎨 App 圖標製作指南

## 📋 需求

### 主圖標
- **尺寸**: 1024x1024 px
- **格式**: PNG（無透明度）
- **設計**: 簡潔、專業、易識別

---

## 🎨 設計建議

### 概念
**智能輸入法 - 忘記切換也能打中文**

### 視覺元素
1. **主元素**: 鍵盤 + 中文字符
2. **顏色**: 藍色/綠色（科技感）
3. **風格**: 扁平化、現代

### 設計方案

#### 方案 1：鍵盤 + 注音符號
```
┌─────────────────┐
│                 │
│   ⌨️  ㄅㄆㄇㄈ   │
│   ⌨️  你好      │
│                 │
└─────────────────┘
```

#### 方案 2：智能檢測圖示
```
┌─────────────────┐
│                 │
│   ABC → 你好    │
│   🔄 智能      │
│                 │
└─────────────────┘
```

#### 方案 3：簡約圖標
```
┌─────────────────┐
│                 │
│      🔤         │
│      中         │
│                 │
└─────────────────┘
```

---

## 🛠️ 製作工具

### 線上工具（免費）
1. **Canva** - https://www.canva.com
   - 簡單易用
   - 有模板

2. **Figma** - https://www.figma.com
   - 專業設計工具
   - 免費版足夠

3. **Photopea** - https://www.photopea.com
   - 線上 Photoshop
   - 完全免費

### 桌面工具
1. **Sketch** - macOS 專用（付費）
2. **Affinity Designer** - 一次性購買
3. **GIMP** - 免費開源

---

## 📐 所需尺寸

### macOS 圖標尺寸
創建以下尺寸的 PNG 文件：

```
icon_16x16.png       (16x16)
icon_16x16@2x.png    (32x32)
icon_32x32.png       (32x32)
icon_32x32@2x.png    (64x64)
icon_128x128.png     (128x128)
icon_128x128@2x.png  (256x256)
icon_256x256.png     (256x256)
icon_256x256@2x.png  (512x512)
icon_512x512.png     (512x512)
icon_512x512@2x.png  (1024x1024)
```

---

## 🚀 快速製作步驟

### 步驟 1：設計主圖標（1024x1024）

1. 打開 Canva 或 Figma
2. 創建 1024x1024 畫布
3. 選擇背景顏色（建議：藍色漸層）
4. 添加圖標元素：
   - 鍵盤圖示
   - 中文字符（你好）
   - 或注音符號（ㄅㄆㄇ）
5. 導出為 PNG

### 步驟 2：生成所有尺寸

#### 選項 A：使用線上工具
訪問：https://appicon.co
- 上傳 1024x1024 圖標
- 自動生成所有尺寸
- 下載 iconset

#### 選項 B：使用 macOS 命令
```bash
# 假設你有 icon_1024.png
cd Resources/AppIcon.iconset

# 使用 sips 命令調整尺寸
sips -z 16 16     icon_1024.png --out icon_16x16.png
sips -z 32 32     icon_1024.png --out icon_16x16@2x.png
sips -z 32 32     icon_1024.png --out icon_32x32.png
sips -z 64 64     icon_1024.png --out icon_32x32@2x.png
sips -z 128 128   icon_1024.png --out icon_128x128.png
sips -z 256 256   icon_1024.png --out icon_128x128@2x.png
sips -z 256 256   icon_1024.png --out icon_256x256.png
sips -z 512 512   icon_1024.png --out icon_256x256@2x.png
sips -z 512 512   icon_1024.png --out icon_512x512.png
sips -z 1024 1024 icon_1024.png --out icon_512x512@2x.png

# 生成 .icns 文件
iconutil -c icns AppIcon.iconset -o AppIcon.icns
```

---

## 🎨 簡單設計範例

### 使用 SF Symbols（macOS 內建）

創建一個簡單的圖標：

```bash
# 使用 SF Symbols 創建圖標
# 1. 打開 SF Symbols app（macOS 內建）
# 2. 搜索 "keyboard" 或 "textformat"
# 3. 導出為 PNG
# 4. 使用 Preview 添加背景顏色
```

---

## 📦 放置位置

將生成的圖標放在：
```
macOS/Resources/AppIcon.iconset/
├── icon_16x16.png
├── icon_16x16@2x.png
├── icon_32x32.png
├── icon_32x32@2x.png
├── icon_128x128.png
├── icon_128x128@2x.png
├── icon_256x256.png
├── icon_256x256@2x.png
├── icon_512x512.png
└── icon_512x512@2x.png
```

然後生成 .icns：
```bash
cd macOS/Resources
iconutil -c icns AppIcon.iconset -o AppIcon.icns
```

---

## ⚡ 快速方案（暫時使用）

如果你想快速測試，可以暫時使用系統圖標：

```bash
# 複製系統圖標作為臨時方案
cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns \
   macOS/Resources/AppIcon.icns
```

**注意**: 這只是臨時方案，上架前必須使用自己的圖標！

---

## ✅ 檢查清單

- [ ] 設計 1024x1024 主圖標
- [ ] 生成所有尺寸（16-1024）
- [ ] 創建 .icns 文件
- [ ] 放置到 Resources/ 目錄
- [ ] 更新 Info.plist（已完成）
- [ ] 測試圖標顯示

---

## 💡 提示

1. **保持簡潔**: 圖標在小尺寸時也要清晰
2. **避免文字**: 小圖標上的文字難以閱讀
3. **使用對比**: 確保圖標在淺色和深色背景上都清晰
4. **測試多種尺寸**: 在 Finder 中測試不同尺寸的顯示效果

---

## 🎯 下一步

完成圖標後，繼續：
1. 創建 .app 包結構
2. 簽名 App
3. 創建 DMG 安裝器

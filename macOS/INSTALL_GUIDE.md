# 📦 安裝指南 - 智能輸入法

## ⚠️ 重要說明

**macOS 輸入法不能像普通 App 一樣雙擊運行！**

輸入法必須：
1. 安裝到正確的位置
2. 通過系統偏好設定啟用
3. 由系統的 InputMethodKit 框架啟動

---

## 🚀 正確的安裝步驟

### 方法 1：從 DMG 安裝（推薦）

#### 步驟 1：打開 DMG
```bash
open build/SmartInputMethod-1.0.0.dmg
```

#### 步驟 2：安裝到正確位置

**重要**：輸入法必須安裝到以下位置之一：

1. **用戶級別**（推薦，不需要管理員權限）：
   ```bash
   ~/Library/Input Methods/
   ```

2. **系統級別**（需要管理員權限）：
   ```bash
   /Library/Input Methods/
   ```

**安裝命令**：
```bash
# 創建目錄（如果不存在）
mkdir -p ~/Library/Input\ Methods/

# 複製 App
cp -R /Volumes/SmartInputMethod/SmartInputMethod.app ~/Library/Input\ Methods/

# 或者，如果已經有 build 目錄
cp -R build/SmartInputMethod.app ~/Library/Input\ Methods/
```

#### 步驟 3：重新登入或重啟

**重要**：安裝後需要：
- 登出並重新登入，或
- 重啟電腦

這樣系統才能識別新的輸入法。

#### 步驟 4：啟用輸入法

1. 打開「系統偏好設定」
2. 選擇「鍵盤」
3. 點擊「輸入法」標籤
4. 點擊左下角「+」按鈕
5. 找到「智能輸入法」（SmartInputMethod）
6. 點擊「加入」

#### 步驟 5：使用輸入法

- 按 `Control + Space` 或 `Command + Space` 切換輸入法
- 選擇「智能輸入法」
- 開始輸入！

---

### 方法 2：命令行安裝（快速測試）

```bash
#!/bin/bash

# 一鍵安裝腳本
cd /Users/jaywang/Desktop/輸入法/macOS

# 1. 創建目錄
mkdir -p ~/Library/Input\ Methods/

# 2. 移除舊版本（如果存在）
rm -rf ~/Library/Input\ Methods/SmartInputMethod.app

# 3. 複製新版本
cp -R build/SmartInputMethod.app ~/Library/Input\ Methods/

# 4. 設置權限
chmod -R 755 ~/Library/Input\ Methods/SmartInputMethod.app

# 5. 重新加載輸入法
killall -9 "System Preferences" 2>/dev/null || true

echo "✅ 安裝完成！"
echo ""
echo "🔄 下一步："
echo "1. 登出並重新登入（或重啟電腦）"
echo "2. 打開「系統偏好設定」→「鍵盤」→「輸入法」"
echo "3. 點擊「+」添加「智能輸入法」"
echo "4. 開始使用！"
```

---

## 🔧 故障排除

### 問題 1：找不到輸入法

**原因**：
- 安裝位置錯誤
- 未重新登入

**解決方案**：
```bash
# 1. 檢查安裝位置
ls -la ~/Library/Input\ Methods/SmartInputMethod.app

# 2. 如果不存在，重新安裝
cp -R build/SmartInputMethod.app ~/Library/Input\ Methods/

# 3. 登出並重新登入
```

---

### 問題 2：輸入法崩潰

**原因**：
- 嘗試直接雙擊運行（錯誤！）
- 權限問題
- Info.plist 配置錯誤

**解決方案**：
```bash
# 1. 檢查權限
chmod -R 755 ~/Library/Input\ Methods/SmartInputMethod.app

# 2. 檢查 Info.plist
plutil -lint ~/Library/Input\ Methods/SmartInputMethod.app/Contents/Info.plist

# 3. 查看系統日誌
log show --predicate 'process == "SmartInputMethod"' --last 5m
```

---

### 問題 3：輸入法不回應

**原因**：
- 輸入法服務未正確啟動
- 權限不足

**解決方案**：
```bash
# 1. 檢查輸入法進程
ps aux | grep SmartInputMethod

# 2. 重新啟動輸入法（在系統偏好設定中）

# 3. 檢查權限
# 系統偏好設定 → 安全性與隱私 → 輔助功能
# 確保允許 SmartInputMethod
```

---

## 📝 驗證安裝

### 1. 檢查文件存在
```bash
ls -la ~/Library/Input\ Methods/SmartInputMethod.app
```

### 2. 檢查 Info.plist
```bash
plutil -lint ~/Library/Input\ Methods/SmartInputMethod.app/Contents/Info.plist
```

### 3. 檢查可執行文件
```bash
file ~/Library/Input\ Methods/SmartInputMethod.app/Contents/MacOS/SmartInputMethod
```

### 4. 檢查輸入法列表
```bash
# 重新登入後，在終端機執行
defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleEnabledInputSources
```

---

## ⚠️ 常見錯誤

### ❌ 錯誤做法

```bash
# 1. 直接雙擊 .app（會崩潰！）
open SmartInputMethod.app  # ❌

# 2. 安裝到 Applications（無法識別！）
cp SmartInputMethod.app /Applications/  # ❌

# 3. 不重新登入（無法載入！）
# 安裝後不登出  # ❌
```

### ✅ 正確做法

```bash
# 1. 安裝到 Input Methods
cp -R SmartInputMethod.app ~/Library/Input\ Methods/  # ✅

# 2. 重新登入或重啟
# 登出並重新登入  # ✅

# 3. 在系統偏好設定中啟用
# 系統偏好設定 → 鍵盤 → 輸入法 → +  # ✅
```

---

## 🎯 快速安裝（一鍵）

創建 `install.sh`：

```bash
#!/bin/bash

echo "📦 安裝智能輸入法..."
echo "=================================================="

# 1. 檢查 App 是否存在
if [ ! -d "build/SmartInputMethod.app" ]; then
    echo "❌ 錯誤：找不到 SmartInputMethod.app"
    echo "請先運行 ./build_complete.sh 編譯 App"
    exit 1
fi

# 2. 創建目錄
echo "📁 創建目錄..."
mkdir -p ~/Library/Input\ Methods/

# 3. 移除舊版本
if [ -d ~/Library/Input\ Methods/SmartInputMethod.app ]; then
    echo "🗑️  移除舊版本..."
    rm -rf ~/Library/Input\ Methods/SmartInputMethod.app
fi

# 4. 複製新版本
echo "📋 複製 App..."
cp -R build/SmartInputMethod.app ~/Library/Input\ Methods/

# 5. 設置權限
echo "🔐 設置權限..."
chmod -R 755 ~/Library/Input\ Methods/SmartInputMethod.app

# 6. 驗證安裝
echo ""
echo "🔍 驗證安裝..."
if [ -d ~/Library/Input\ Methods/SmartInputMethod.app ]; then
    echo "✅ 安裝成功！"
    echo ""
    echo "📍 安裝位置: ~/Library/Input Methods/SmartInputMethod.app"
    ls -lh ~/Library/Input\ Methods/SmartInputMethod.app
else
    echo "❌ 安裝失敗！"
    exit 1
fi

echo ""
echo "=================================================="
echo "🎯 下一步（重要！）："
echo ""
echo "1. 🔄 登出並重新登入（或重啟電腦）"
echo "   - 點擊 Apple 選單 → 登出"
echo "   - 重新登入"
echo ""
echo "2. ⚙️  啟用輸入法"
echo "   - 打開「系統偏好設定」"
echo "   - 選擇「鍵盤」→「輸入法」"
echo "   - 點擊「+」添加「智能輸入法」"
echo ""
echo "3. 🎉 開始使用"
echo "   - 按 Control+Space 切換輸入法"
echo "   - 選擇「智能輸入法」"
echo "   - 輸入 su3cl3 → 你好"
echo ""
echo "⚠️  注意：不要直接雙擊 .app 運行，會崩潰！"
echo ""
```

保存並運行：
```bash
chmod +x install.sh
./install.sh
```

---

## 📞 需要幫助？

1. **安裝問題**：檢查安裝位置是否正確
2. **崩潰問題**：不要直接雙擊運行！
3. **無法找到**：確認已重新登入
4. **權限問題**：檢查「輔助功能」權限

---

## 💡 重要提示

1. **輸入法 ≠ 普通 App**：不能直接運行
2. **必須安裝到 Input Methods**：其他位置無效
3. **必須重新登入**：系統才能識別
4. **必須在系統偏好設定中啟用**：才能使用

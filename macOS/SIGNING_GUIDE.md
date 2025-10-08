# 🔐 App 簽名與公證指南

## 📋 前提條件

### 必需
1. **Apple Developer Account** ($99/年)
   - 已註冊並激活
   - 訪問：https://developer.apple.com

2. **Developer ID Certificate**
   - 類型：Developer ID Application
   - 用於簽名 macOS 應用

3. **App-Specific Password**
   - 用於公證（notarization）
   - 在 Apple ID 帳戶設置中生成

---

## 🔑 步驟 1：獲取 Developer ID Certificate

### 1.1 在 Keychain Access 中請求證書

```bash
# 打開 Keychain Access
open /Applications/Utilities/Keychain\ Access.app
```

1. 選單：**Keychain Access** → **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
2. 填寫：
   - User Email Address: 你的 Apple ID
   - Common Name: 你的名字
   - Request is: **Saved to disk**
3. 保存 `CertificateSigningRequest.certSigningRequest`

### 1.2 在 Apple Developer 網站創建證書

1. 訪問：https://developer.apple.com/account/resources/certificates/list
2. 點擊「+」創建新證書
3. 選擇：**Developer ID Application**
4. 上傳剛才的 `.certSigningRequest` 文件
5. 下載 `.cer` 文件
6. 雙擊安裝到 Keychain

### 1.3 驗證證書

```bash
# 查看可用的簽名身份
security find-identity -v -p codesigning

# 應該看到類似：
# 1) XXXXX "Developer ID Application: Your Name (TEAM_ID)"
```

---

## ✍️ 步驟 2：簽名 App

### 2.1 基本簽名

```bash
# 簽名 .app
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --options runtime \
    build/SmartInputMethod.app

# 驗證簽名
codesign --verify --deep --strict --verbose=2 \
    build/SmartInputMethod.app

# 檢查簽名信息
codesign -dv --verbose=4 build/SmartInputMethod.app
```

### 2.2 使用腳本簽名

創建 `sign_app.sh`：

```bash
#!/bin/bash

# 設置你的簽名身份
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# 簽名
codesign --deep --force --verify --verbose \
    --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    build/SmartInputMethod.app

# 驗證
codesign --verify --deep --strict --verbose=2 \
    build/SmartInputMethod.app

echo "✅ 簽名完成"
```

---

## 📝 步驟 3：公證 App

### 3.1 生成 App-Specific Password

1. 訪問：https://appleid.apple.com
2. 登入你的 Apple ID
3. 選擇「安全性」→「App 專用密碼」
4. 點擊「生成密碼」
5. 保存密碼（例如：`xxxx-xxxx-xxxx-xxxx`）

### 3.2 創建 DMG 並公證

```bash
# 1. 創建 DMG
hdiutil create -volname "SmartInputMethod" \
    -srcfolder build/SmartInputMethod.app \
    -ov -format UDZO \
    build/SmartInputMethod-1.0.0.dmg

# 2. 簽名 DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    build/SmartInputMethod-1.0.0.dmg

# 3. 上傳公證
xcrun notarytool submit build/SmartInputMethod-1.0.0.dmg \
    --apple-id "your@email.com" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --team-id "TEAM_ID" \
    --wait

# 4. 裝訂公證票據
xcrun stapler staple build/SmartInputMethod.app

# 5. 驗證公證
spctl -a -vvv -t install build/SmartInputMethod.app
```

### 3.3 使用腳本公證

創建 `notarize_app.sh`：

```bash
#!/bin/bash

# 設置變量
APPLE_ID="your@email.com"
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
TEAM_ID="TEAM_ID"
DMG_PATH="build/SmartInputMethod-1.0.0.dmg"

# 上傳公證
echo "📤 上傳公證..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# 裝訂公證票據
echo "📎 裝訂公證票據..."
xcrun stapler staple build/SmartInputMethod.app

# 驗證
echo "✅ 驗證公證..."
spctl -a -vvv -t install build/SmartInputMethod.app

echo "🎉 公證完成！"
```

---

## 🚀 步驟 4：完整打包流程

### 4.1 一鍵打包腳本

創建 `build_and_sign.sh`：

```bash
#!/bin/bash

set -e

echo "🚀 開始完整打包流程..."

# 1. 編譯
echo "📦 編譯..."
./build_with_smart_engine.sh

# 2. 創建 .app 包
echo "📁 創建 .app 包..."
./create_app_bundle.sh

# 3. 簽名（如果有證書）
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "✍️  簽名 App..."
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    codesign --deep --force --verify --verbose \
        --sign "$SIGNING_IDENTITY" \
        --options runtime \
        build/SmartInputMethod.app
    echo "✅ 簽名完成"
else
    echo "⚠️  未找到簽名證書，跳過簽名"
fi

# 4. 創建 DMG
echo "💿 創建 DMG..."
./create_dmg.sh

echo "🎉 打包完成！"
echo "📍 DMG 位置: build/SmartInputMethod-1.0.0.dmg"
```

---

## 🧪 步驟 5：測試

### 5.1 本地測試

```bash
# 測試 .app
open build/SmartInputMethod.app

# 測試 DMG
open build/SmartInputMethod-1.0.0.dmg
```

### 5.2 驗證簽名

```bash
# 驗證 .app 簽名
codesign --verify --deep --strict --verbose=2 \
    build/SmartInputMethod.app

# 驗證 DMG 簽名
codesign --verify --deep --strict --verbose=2 \
    build/SmartInputMethod-1.0.0.dmg

# 檢查 Gatekeeper
spctl -a -vvv -t install build/SmartInputMethod.app
```

---

## ⚠️ 常見問題

### 問題 1：找不到簽名身份

**解決方案**：
```bash
# 檢查證書
security find-identity -v -p codesigning

# 如果沒有，重新下載並安裝證書
```

### 問題 2：公證失敗

**可能原因**：
- App-Specific Password 錯誤
- Team ID 錯誤
- App 未正確簽名

**解決方案**：
```bash
# 檢查公證狀態
xcrun notarytool history --apple-id "your@email.com" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --team-id "TEAM_ID"

# 查看詳細錯誤
xcrun notarytool log <submission-id> \
    --apple-id "your@email.com" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --team-id "TEAM_ID"
```

### 問題 3：Gatekeeper 阻止運行

**解決方案**：
```bash
# 臨時允許運行（測試用）
xattr -cr build/SmartInputMethod.app

# 或在系統偏好設定中允許
```

---

## 📝 檢查清單

### 簽名前
- [ ] Apple Developer Account 已激活
- [ ] Developer ID Certificate 已安裝
- [ ] 證書在 Keychain 中可見
- [ ] .app 包結構正確

### 簽名後
- [ ] 簽名驗證通過
- [ ] 可以本地運行
- [ ] Gatekeeper 不阻止

### 公證後
- [ ] 公證成功
- [ ] 票據已裝訂
- [ ] spctl 驗證通過
- [ ] 可以在其他 Mac 上安裝

---

## 🎯 下一步

完成簽名和公證後：
1. 測試安裝流程
2. 準備 App Store 資料
3. 提交審核

---

## 💡 提示

1. **開發階段**：可以不簽名，直接測試功能
2. **分發階段**：必須簽名，否則 Gatekeeper 會阻止
3. **App Store**：必須簽名和公證
4. **保存密碼**：App-Specific Password 只顯示一次

---

## 📞 需要幫助？

- Apple Developer 文檔：https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- 簽名指南：https://developer.apple.com/library/archive/technotes/tn2206/
- 公證指南：https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

#!/bin/bash

# 一鍵安裝腳本 - 智能輸入法

echo "📦 安裝智能輸入法..."
echo "=================================================="
echo ""

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
echo "📋 複製 App 到 ~/Library/Input Methods/..."
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
    echo "📍 安裝位置:"
    ls -lh ~/Library/Input\ Methods/ | grep SmartInputMethod
    echo ""
    echo "📊 App 大小:"
    du -sh ~/Library/Input\ Methods/SmartInputMethod.app
else
    echo "❌ 安裝失敗！"
    exit 1
fi

echo ""
echo "=================================================="
echo "🎯 下一步（重要！）："
echo "=================================================="
echo ""
echo "1. 🔄 重新登入系統"
echo "   ⚠️  這一步是必須的！系統需要重新載入輸入法列表"
echo "   - 點擊 Apple 選單（）→ 登出"
echo "   - 重新登入你的帳號"
echo ""
echo "2. ⚙️  啟用輸入法"
echo "   - 打開「系統偏好設定」"
echo "   - 選擇「鍵盤」→「輸入法」"
echo "   - 點擊左下角「+」按鈕"
echo "   - 找到「智能輸入法」或「SmartInputMethod」"
echo "   - 點擊「加入」"
echo ""
echo "3. 🎉 開始使用"
echo "   - 按 Control+Space 或 Command+Space 切換輸入法"
echo "   - 選擇「智能輸入法」"
echo "   - 測試輸入："
echo "     • su3cl3 → 你好"
echo "     • hello → hello"
echo "     • j3 → 我"
echo ""
echo "=================================================="
echo "⚠️  重要警告："
echo "=================================================="
echo ""
echo "❌ 不要直接雙擊 SmartInputMethod.app！"
echo "   - macOS 輸入法不能像普通 App 一樣運行"
echo "   - 必須通過系統偏好設定啟用"
echo "   - 直接運行會導致崩潰"
echo ""
echo "✅ 正確的使用方式："
echo "   - 在系統偏好設定中啟用"
echo "   - 使用快捷鍵切換"
echo ""
echo "=================================================="
echo "📞 需要幫助？查看 INSTALL_GUIDE.md"
echo "=================================================="
echo ""

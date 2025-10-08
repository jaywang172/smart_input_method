#!/bin/bash

# 創建 DMG 安裝器

set -e  # 遇到錯誤立即退出

echo "💿 創建 DMG 安裝器..."
echo "=================================================="

# 定義變量
APP_NAME="SmartInputMethod"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-1.0.0"
BUILD_DIR="build"
DMG_TEMP="dmg_temp"

# 檢查 .app 包是否存在
if [ ! -d "$BUILD_DIR/$APP_BUNDLE" ]; then
    echo "❌ 錯誤：找不到 $BUILD_DIR/$APP_BUNDLE"
    echo "請先運行 ./create_app_bundle.sh"
    exit 1
fi

# 清理舊的臨時文件
echo "🗑️  清理舊文件..."
rm -rf "$BUILD_DIR/$DMG_TEMP"
rm -f "$BUILD_DIR/$DMG_NAME.dmg"

# 創建臨時目錄
echo "📁 創建臨時目錄..."
mkdir -p "$BUILD_DIR/$DMG_TEMP"

# 複製 .app 到臨時目錄
echo "📋 複製 App..."
cp -R "$BUILD_DIR/$APP_BUNDLE" "$BUILD_DIR/$DMG_TEMP/"

# 創建 Applications 快捷方式
echo "🔗 創建 Applications 快捷方式..."
ln -s /Applications "$BUILD_DIR/$DMG_TEMP/Applications"

# 創建 README
echo "📄 創建 README..."
cat > "$BUILD_DIR/$DMG_TEMP/README.txt" << 'EOF'
智能輸入法 - 安裝說明

1. 將 SmartInputMethod.app 拖曳到 Applications 資料夾
2. 打開「系統偏好設定」→「鍵盤」→「輸入法」
3. 點擊「+」添加「智能輸入法」
4. 開始使用！

功能特點：
• 自動檢測輸入類型（注音 vs 英文）
• 無需手動切換輸入法
• 忘記切換也能打中文

系統需求：
• macOS 10.15 或更高版本

問題回報：
• 請訪問我們的網站或聯繫支援

© 2025 Smart Input Method. All rights reserved.
EOF

# 創建 DMG
echo "💿 創建 DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$BUILD_DIR/$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME.dmg"

if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "✅ DMG 創建成功！"
    echo ""
    echo "📍 位置: $BUILD_DIR/$DMG_NAME.dmg"
    echo "📦 大小: $(du -h "$BUILD_DIR/$DMG_NAME.dmg" | cut -f1)"
    echo ""
    echo "🎯 下一步："
    echo "  1. 測試 DMG: open $BUILD_DIR/$DMG_NAME.dmg"
    echo "  2. 測試安裝流程"
    echo "  3. 如果有 Developer ID，進行簽名和公證"
    echo ""
    echo "💡 提示："
    echo "  - 上架 App Store 前需要簽名和公證"
    echo "  - 可以先測試安裝和功能"
    echo ""
    
    # 清理臨時文件
    echo "🗑️  清理臨時文件..."
    rm -rf "$BUILD_DIR/$DMG_TEMP"
    echo "✅ 清理完成"
else
    echo "❌ DMG 創建失敗！"
    exit 1
fi

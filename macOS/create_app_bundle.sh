#!/bin/bash

# 創建完整的 .app 包結構

set -e  # 遇到錯誤立即退出

echo "📦 創建 SmartInputMethod.app 包結構..."
echo "=================================================="

# 定義變量
APP_NAME="SmartInputMethod"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="build"
RESOURCES_DIR="Resources"

# 清理舊的 .app 包
if [ -d "$BUILD_DIR/$APP_BUNDLE" ]; then
    echo "🗑️  清理舊的 .app 包..."
    rm -rf "$BUILD_DIR/$APP_BUNDLE"
fi

# 創建 .app 包結構
echo "📁 創建目錄結構..."
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/Resources"

# 複製可執行文件
echo "📋 複製可執行文件..."
if [ -f "$BUILD_DIR/$APP_NAME" ]; then
    cp "$BUILD_DIR/$APP_NAME" "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/"
    chmod +x "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    echo "✅ 可執行文件已複製"
else
    echo "❌ 錯誤：找不到可執行文件 $BUILD_DIR/$APP_NAME"
    echo "請先運行 ./build_with_smart_engine.sh"
    exit 1
fi

# 複製 Info.plist
echo "📋 複製 Info.plist..."
if [ -f "Info.plist" ]; then
    cp "Info.plist" "$BUILD_DIR/$APP_BUNDLE/Contents/"
    echo "✅ Info.plist 已複製"
else
    echo "❌ 錯誤：找不到 Info.plist"
    exit 1
fi

# 複製圖標
echo "🎨 複製 App 圖標..."
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$BUILD_DIR/$APP_BUNDLE/Contents/Resources/"
    echo "✅ App 圖標已複製"
else
    echo "⚠️  警告：找不到 AppIcon.icns，使用預設圖標"
fi

# 創建 PkgInfo 文件
echo "📄 創建 PkgInfo..."
echo -n "APPL????" > "$BUILD_DIR/$APP_BUNDLE/Contents/PkgInfo"

# 驗證 .app 包結構
echo ""
echo "🔍 驗證 .app 包結構..."
echo "=================================================="
ls -la "$BUILD_DIR/$APP_BUNDLE/Contents/"
echo ""
ls -la "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/"
echo ""
ls -la "$BUILD_DIR/$APP_BUNDLE/Contents/Resources/"

echo ""
echo "=================================================="
echo "✅ .app 包創建成功！"
echo ""
echo "📍 位置: $BUILD_DIR/$APP_BUNDLE"
echo ""
echo "🎯 下一步："
echo "  1. 測試 App: open $BUILD_DIR/$APP_BUNDLE"
echo "  2. 或繼續簽名和打包"
echo ""
echo "💡 提示："
echo "  - 上架前記得更換 AppIcon.icns"
echo "  - 確認 Bundle ID 正確"
echo "  - 準備好 Developer ID Certificate"
echo ""

#!/bin/bash

# 完整的打包流程：編譯 → 創建 .app → 創建 DMG

set -e  # 遇到錯誤立即退出

echo "🚀 開始完整打包流程..."
echo "=================================================="
echo ""

# 步驟 1：編譯
echo "📦 步驟 1/3：編譯 App..."
echo "=================================================="
./build_with_smart_engine.sh
echo ""

# 步驟 2：創建 .app 包
echo "📁 步驟 2/3：創建 .app 包..."
echo "=================================================="
./create_app_bundle.sh
echo ""

# 步驟 3：創建 DMG
echo "💿 步驟 3/3：創建 DMG 安裝器..."
echo "=================================================="
./create_dmg.sh
echo ""

# 完成
echo "=================================================="
echo "🎉 完整打包流程完成！"
echo "=================================================="
echo ""
echo "📦 產出文件："
echo "  ✅ build/SmartInputMethod (可執行文件)"
echo "  ✅ build/SmartInputMethod.app (App 包)"
echo "  ✅ build/SmartInputMethod-1.0.0.dmg (DMG 安裝器)"
echo ""
echo "📊 文件大小："
ls -lh build/SmartInputMethod build/SmartInputMethod-1.0.0.dmg | awk '{print "  ", $9, "-", $5}'
echo ""
echo "🎯 下一步："
echo "  1. 測試 DMG: open build/SmartInputMethod-1.0.0.dmg"
echo "  2. 測試安裝: 將 App 拖到 Applications"
echo "  3. 測試功能: 在系統偏好設定中啟用輸入法"
echo ""
echo "💡 提示："
echo "  - 如果有 Developer ID，可以進行簽名和公證"
echo "  - 查看 SIGNING_GUIDE.md 了解簽名步驟"
echo "  - 上架前記得更換 AppIcon.icns"
echo ""

#!/bin/bash

echo "🚀 編譯 macOS 智能輸入法應用程式..."

# 創建構建目錄
mkdir -p build

# 編譯所有 Swift 檔案
swiftc \
    -target x86_64-apple-macos10.15 \
    -import-objc-header BridgingHeader.h \
    ../DataStructures/*.swift \
    ../Core/*.swift \
    ../ML/*.swift \
    *.swift \
    -o build/SmartInputMethod

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功！"
    
    # 創建應用程式包
    echo "📦 創建應用程式包..."
    
    # 創建 .app 目錄結構
    mkdir -p "SmartInputMethod.app/Contents/MacOS"
    mkdir -p "SmartInputMethod.app/Contents/Resources"
    
    # 複製可執行檔案
    cp build/SmartInputMethod "SmartInputMethod.app/Contents/MacOS/"
    
    # 複製 Info.plist
    cp Info.plist "SmartInputMethod.app/Contents/"
    
    # 設置權限
    chmod +x "SmartInputMethod.app/Contents/MacOS/SmartInputMethod"
    
    echo "✅ 應用程式包創建完成！"
    echo "📱 應用程式位置: SmartInputMethod.app"
    echo "🚀 運行命令: open SmartInputMethod.app"
    
else
    echo "❌ 編譯失敗"
    exit 1
fi

#!/bin/bash

# 編譯包含智能引擎的 macOS 輸入法

set -e  # 遇到錯誤立即退出

echo "🚀 編譯 macOS 智能輸入法（包含 SmartInputEngine）..."
echo "=================================================="

# 創建 build 目錄
mkdir -p build

# 編譯（包含所有必要的文件）
echo "📦 編譯中..."

swiftc -o build/SmartInputMethod \
    -framework Cocoa \
    -framework Carbon \
    -framework InputMethodKit \
    ../Core/KeyboardMapper.swift \
    ../Core/DictionaryLookup.swift \
    ../Core/SmartInputEngine.swift \
    ../Core/InputEngine.swift \
    ../Core/InputEngineConfig.swift \
    ../Core/LanguageDetector.swift \
    ../Core/BopomofoConverter.swift \
    ../Core/CandidateFusion.swift \
    ../Core/UserDictionary.swift \
    ../Core/Telemetry.swift \
    ../Core/PerformanceDashboard.swift \
    ../Core/LanguageDetectionFusion.swift \
    ../Core/ThreadSafeSnapshot.swift \
    ../Core/ResourceManager.swift \
    ../Core/ResourceManifest.swift \
    ../Core/SDKVersion.swift \
    ../DataStructures/Trie.swift \
    ../DataStructures/RadixTrie.swift \
    ../DataStructures/WordLookup.swift \
    ../DataStructures/NgramModel.swift \
    ../ML/LanguageClassifier.swift \
    main.swift \
    AppDelegate.swift \
    InputMethodServer.swift \
    CandidateWindow.swift \
    InputMethodController.swift

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功！"
    echo ""
    echo "📍 可執行文件位置: build/SmartInputMethod"
    echo ""
    echo "🎯 下一步："
    echo "  1. 運行測試: ./build/SmartInputMethod"
    echo "  2. 或創建 .app 包並安裝到系統"
    echo ""
else
    echo "❌ 編譯失敗！"
    exit 1
fi

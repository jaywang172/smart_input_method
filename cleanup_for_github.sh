#!/bin/bash

# GitHub 清理腳本 - 準備上傳前清理所有編譯產物和臨時文件

echo "🧹 清理專案，準備上傳到 GitHub..."
echo "=================================================="
echo ""

# 1. 清理編譯產物
echo "1️⃣ 清理編譯產物..."
rm -rf .build/
rm -rf build/
rm -rf .swiftpm/
rm -rf DerivedData/
echo "✅ 編譯產物已清理"
echo ""

# 2. 清理 macOS 系統文件
echo "2️⃣ 清理 macOS 系統文件..."
find . -name ".DS_Store" -delete
find . -name "._*" -delete
echo "✅ 系統文件已清理"
echo ""

# 3. 清理測試和演示文件
echo "3️⃣ 清理測試和演示文件..."
rm -f test_smart_engine.swift
rm -f main.swift
rm -f macOS/test_*.swift
rm -f macOS/*_test.swift
rm -f macOS/*_demo.swift
rm -f macOS/simple_smart_output.swift
rm -f macOS/truly_smart_input.swift
rm -f macOS/stable_test.swift
echo "✅ 測試文件已清理"
echo ""

# 4. 清理臨時文檔（保留重要文檔）
echo "4️⃣ 清理臨時文檔..."
rm -f CRASH_FIXED.md
rm -f STAGE2_COMPLETE.md
rm -f STAGE3_COMPLETE.md
rm -f PROGRESS_REPORT.md
rm -f CODE_REVIEW_SUMMARY.md
rm -f CLEANUP_SCRIPT.sh
echo "✅ 臨時文檔已清理"
echo ""

# 5. 清理 macOS 臨時腳本
echo "5️⃣ 清理 macOS 臨時腳本..."
rm -f macOS/diagnose.sh
rm -f macOS/build_core.sh
echo "✅ 臨時腳本已清理"
echo ""

# 6. 保留的重要文件列表
echo "6️⃣ 保留的重要文件："
echo ""
echo "📚 文檔:"
echo "  - README.md"
echo "  - QUICK_START.md"
echo "  - CODE_REVIEW.md"
echo "  - APP_STORE_ROADMAP.md"
echo "  - EXECUTIVE_SUMMARY.md"
echo "  - INSTALL_GUIDE.md (macOS)"
echo "  - SIGNING_GUIDE.md (macOS)"
echo "  - TESTING_GUIDE.md (macOS)"
echo ""
echo "🔧 核心代碼:"
echo "  - Core/"
echo "  - DataStructures/"
echo "  - ML/"
echo "  - Tests/"
echo ""
echo "📦 macOS 應用:"
echo "  - macOS/"
echo "  - build_complete.sh"
echo "  - install.sh"
echo ""
echo "⚙️  配置:"
echo "  - Package.swift"
echo "  - .gitignore"
echo ""

# 7. 顯示當前目錄結構
echo "7️⃣ 當前目錄結構:"
ls -la | grep -v "^d" | grep -v "total" | tail -20
echo ""

# 8. 統計
echo "8️⃣ 統計信息:"
echo "總文件數: $(find . -type f | wc -l | xargs)"
echo "總目錄數: $(find . -type d | wc -l | xargs)"
echo "代碼文件數: $(find . -name "*.swift" | wc -l | xargs)"
echo ""

echo "=================================================="
echo "✅ 清理完成！專案已準備好上傳到 GitHub"
echo ""
echo "🚀 下一步："
echo "1. git init"
echo "2. git add ."
echo "3. git commit -m \"Initial commit\""
echo "4. git remote add origin https://github.com/jaywang172/smart_input_method.git"
echo "5. git branch -M main"
echo "6. git push -u origin main"
echo ""


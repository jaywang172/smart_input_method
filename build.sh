#!/bin/bash

# 智能混合輸入法 - 建置腳本

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印帶顏色的訊息
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# 顯示標題
echo "════════════════════════════════════════════════════════════"
echo "       智能混合輸入法 - 建置與測試工具"
echo "════════════════════════════════════════════════════════════"
echo ""

# 檢查 Swift 是否安裝
if ! command -v swift &> /dev/null; then
    print_error "Swift 未安裝！請先安裝 Xcode Command Line Tools"
    exit 1
fi

print_success "Swift 版本: $(swift --version | head -n 1)"
echo ""

# 顯示選單
show_menu() {
    echo "請選擇操作："
    echo ""
    echo "  1) 運行主程式 (顯示專案資訊)"
    echo "  2) 查看專案統計"
    echo "  3) 查看檔案結構"
    echo "  4) 查看文檔列表"
    echo "  5) 檢查程式碼語法"
    echo "  6) 清理輸出檔案"
    echo "  7) 建立 Xcode 專案 (說明)"
    echo "  8) 顯示快速參考"
    echo "  0) 退出"
    echo ""
    echo -n "輸入選項 [0-8]: "
}

# 統計程式碼
count_code() {
    print_info "統計程式碼行數..."
    echo ""
    
    echo "Swift 檔案："
    for file in Core/*.swift DataStructures/*.swift ML/*.swift Tests/*.swift main.swift; do
        if [ -f "$file" ]; then
            lines=$(wc -l < "$file")
            printf "  %-40s %6d 行\n" "$file" "$lines"
        fi
    done
    
    echo ""
    echo "文檔檔案："
    for file in *.md; do
        if [ -f "$file" ]; then
            lines=$(wc -l < "$file")
            printf "  %-40s %6d 行\n" "$file" "$lines"
        fi
    done
    
    echo ""
    total_swift=$(find . -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')
    total_md=$(find . -name "*.md" -exec wc -l {} + | tail -1 | awk '{print $1}')
    
    print_success "Swift 總行數: $total_swift"
    print_success "文檔總行數: $total_md"
    print_success "專案總行數: $((total_swift + total_md))"
}

# 顯示檔案結構
show_structure() {
    print_info "專案檔案結構："
    echo ""
    
    if command -v tree &> /dev/null; then
        tree -L 2 -I 'Resources'
    else
        find . -type f \( -name "*.swift" -o -name "*.md" \) -not -path "*/.*" | sort
    fi
}

# 顯示文檔
show_docs() {
    print_info "文檔列表："
    echo ""
    
    echo "📚 主要文檔："
    echo "  1. README.md           - 專案概述"
    echo "  2. ARCHITECTURE.md     - 架構設計"
    echo "  3. ALGORITHMS.md       - 演算法詳解"
    echo "  4. USAGE_GUIDE.md      - 使用指南"
    echo "  5. PROJECT_STRUCTURE.md - 專案結構"
    echo "  6. QUICK_REFERENCE.md  - 快速參考"
    echo "  7. SUMMARY.md          - 專案總結"
    echo ""
    
    echo "要查看某個文檔嗎？輸入文檔編號 (1-7) 或按 Enter 跳過："
    read -r choice
    
    case $choice in
        1) less README.md ;;
        2) less ARCHITECTURE.md ;;
        3) less ALGORITHMS.md ;;
        4) less USAGE_GUIDE.md ;;
        5) less PROJECT_STRUCTURE.md ;;
        6) less QUICK_REFERENCE.md ;;
        7) less SUMMARY.md ;;
        *) ;;
    esac
}

# 語法檢查
check_syntax() {
    print_info "檢查 Swift 檔案語法..."
    echo ""
    
    error_count=0
    
    for file in Core/*.swift DataStructures/*.swift ML/*.swift; do
        if [ -f "$file" ]; then
            echo -n "檢查 $file ... "
            if swift -frontend -parse "$file" &> /dev/null; then
                print_success "通過"
            else
                print_error "發現語法錯誤"
                ((error_count++))
            fi
        fi
    done
    
    echo ""
    if [ $error_count -eq 0 ]; then
        print_success "所有檔案語法正確！"
    else
        print_warning "發現 $error_count 個檔案有語法錯誤"
    fi
}

# 清理檔案
clean() {
    print_info "清理輸出檔案..."
    
    rm -f *.o *.out a.out
    rm -rf build/
    
    print_success "清理完成"
}

# Xcode 專案說明
xcode_guide() {
    print_info "創建 Xcode 專案步驟："
    echo ""
    echo "1. 打開 Xcode"
    echo "2. 選擇 File > New > Project"
    echo "3. 選擇 macOS > App 或 Input Method Extension"
    echo "4. 輸入專案名稱: SmartIME"
    echo "5. 將所有 .swift 檔案拖入專案"
    echo "6. 配置 Info.plist (對於輸入法擴展)"
    echo "7. 編譯和運行"
    echo ""
    echo "詳細說明請參考 USAGE_GUIDE.md"
}

# 快速參考
quick_ref() {
    print_info "快速參考："
    echo ""
    echo "核心類別："
    echo "  • InputEngine      - 主輸入引擎"
    echo "  • Trie             - 前綴樹"
    echo "  • NgramModel       - N-gram 模型"
    echo "  • BopomofoConverter - 注音轉換"
    echo "  • LanguageDetector - 語言檢測"
    echo "  • LanguageClassifier - ML 分類器"
    echo ""
    echo "主要演算法："
    echo "  • Trie 樹          - O(m) 查找"
    echo "  • N-gram           - 統計語言模型"
    echo "  • Viterbi          - O(n×s²) 最佳路徑"
    echo "  • 動態規劃         - 注音分段"
    echo "  • 樸素貝葉斯       - 語言分類"
    echo ""
    echo "詳細資訊請查看 QUICK_REFERENCE.md"
}

# 主迴圈
while true; do
    show_menu
    read -r choice
    echo ""
    
    case $choice in
        1)
            print_info "運行主程式..."
            swift main.swift
            ;;
        2)
            count_code
            ;;
        3)
            show_structure
            ;;
        4)
            show_docs
            ;;
        5)
            check_syntax
            ;;
        6)
            clean
            ;;
        7)
            xcode_guide
            ;;
        8)
            quick_ref
            ;;
        0)
            print_info "再見！"
            exit 0
            ;;
        *)
            print_error "無效的選項"
            ;;
    esac
    
    echo ""
    echo "按 Enter 繼續..."
    read -r
    clear
done

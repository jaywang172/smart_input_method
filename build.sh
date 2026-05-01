#!/bin/bash

# 智能混合輸入法 - 建置與安裝腳本
# 使用 Swift Package Manager 建置

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}ℹ  ${1}${NC}"; }
print_success() { echo -e "${GREEN}✓  ${1}${NC}"; }
print_warning() { echo -e "${YELLOW}⚠  ${1}${NC}"; }
print_error()   { echo -e "${RED}✗  ${1}${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SmartIME"
BUNDLE_ID="com.jaywang.inputmethod.SmartIME"
APP_BUNDLE="${APP_NAME}.app"
INSTALL_DIR="$HOME/Library/Input Methods"

# ═══════════════════════════════════════════════
# 顯示標題
# ═══════════════════════════════════════════════
show_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       SmartIME 智能混合輸入法 建置工具       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# ═══════════════════════════════════════════════
# 檢查環境
# ═══════════════════════════════════════════════
check_env() {
    if ! command -v swift &> /dev/null; then
        print_error "Swift 未安裝！請先安裝 Xcode Command Line Tools"
        echo "  → xcode-select --install"
        exit 1
    fi
    print_success "Swift: $(swift --version 2>&1 | head -n 1)"
}

# ═══════════════════════════════════════════════
# 建置核心引擎
# ═══════════════════════════════════════════════
build_core() {
    print_info "建置 SmartIMECore..."
    cd "$SCRIPT_DIR"
    swift build --product SmartIMECore 2>&1
    print_success "SmartIMECore 建置完成"
}

# ═══════════════════════════════════════════════
# 建置輸入法 App
# ═══════════════════════════════════════════════
build_app() {
    print_info "建置 SmartIMEApp..."
    cd "$SCRIPT_DIR"
    swift build --product SmartIMEApp 2>&1
    print_success "SmartIMEApp 建置完成"
}

# ═══════════════════════════════════════════════
# 執行測試
# ═══════════════════════════════════════════════
run_tests() {
    print_info "執行單元測試..."
    cd "$SCRIPT_DIR"
    swift run SmartIMECoreTests 2>&1
    print_success "測試完成"
}

# ═══════════════════════════════════════════════
# 執行示範
# ═══════════════════════════════════════════════
run_demo() {
    print_info "執行示範程式..."
    cd "$SCRIPT_DIR"
    swift run SmartIMEDemo 2>&1
}

# ═══════════════════════════════════════════════
# 建立 .app bundle
# ═══════════════════════════════════════════════
package_app() {
    print_info "建立 ${APP_BUNDLE}..."
    cd "$SCRIPT_DIR"
    
    # 先建置 release
    swift build --product SmartIMEApp -c release 2>&1
    
    # 找到編譯產出
    local BUILD_DIR
    BUILD_DIR=$(swift build --product SmartIMEApp -c release --show-bin-path 2>/dev/null)
    local EXECUTABLE="${BUILD_DIR}/SmartIMEApp"
    
    if [ ! -f "$EXECUTABLE" ]; then
        print_error "找不到編譯產出: $EXECUTABLE"
        exit 1
    fi
    
    # 建立 .app 目錄結構
    local APP_DIR="${SCRIPT_DIR}/${APP_BUNDLE}"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"
    
    # 複製執行檔
    cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/${APP_NAME}App"
    
    # 複製 Info.plist
    cp "$SCRIPT_DIR/Sources/SmartIMEApp/Info.plist" "$APP_DIR/Contents/"
    
    # 修正 Info.plist 中的執行檔名稱
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}App" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
    
    # 建立 PkgInfo
    echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"
    
    print_success "${APP_BUNDLE} 建立完成: ${APP_DIR}"
    echo ""
    echo "  檔案大小: $(du -sh "$APP_DIR" | cut -f1)"
    echo "  位置: ${APP_DIR}"
}

# ═══════════════════════════════════════════════
# 安裝到系統
# ═══════════════════════════════════════════════
install_app() {
    local APP_DIR="${SCRIPT_DIR}/${APP_BUNDLE}"
    
    if [ ! -d "$APP_DIR" ]; then
        print_warning "${APP_BUNDLE} 尚未建立，先執行建置..."
        package_app
    fi
    
    print_info "安裝到 ${INSTALL_DIR}/..."
    
    # 先停止舊版
    if pgrep -f "${APP_NAME}App" > /dev/null 2>&1; then
        print_info "停止舊版 ${APP_NAME}..."
        killall "${APP_NAME}App" 2>/dev/null || true
        sleep 1
    fi
    
    # 複製到輸入法目錄
    mkdir -p "$INSTALL_DIR"
    rm -rf "${INSTALL_DIR}/${APP_BUNDLE}"
    cp -R "$APP_DIR" "${INSTALL_DIR}/"
    
    print_success "安裝完成！"
    echo ""
    print_warning "請執行以下步驟啟用輸入法："
    echo "  1. 系統設定 → 鍵盤 → 輸入方式 → 新增「SmartIME」"
    echo "  2. 或登出再登入以重新載入輸入法"
    echo ""
    print_info "可以用以下指令手動重新載入："
    echo "  killall imklaunchagent 2>/dev/null; sleep 1"
}

# ═══════════════════════════════════════════════
# 清理
# ═══════════════════════════════════════════════
clean() {
    print_info "清理建置產出..."
    cd "$SCRIPT_DIR"
    swift package clean 2>/dev/null || true
    rm -rf "${SCRIPT_DIR}/${APP_BUNDLE}"
    rm -rf .build
    print_success "清理完成"
}

# ═══════════════════════════════════════════════
# 統計
# ═══════════════════════════════════════════════
stats() {
    print_info "專案統計"
    echo ""
    
    local swift_files=$(find "$SCRIPT_DIR/Sources" "$SCRIPT_DIR/Tests" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    local swift_lines=$(find "$SCRIPT_DIR/Sources" "$SCRIPT_DIR/Tests" -name "*.swift" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    local md_files=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    
    echo "  Swift 檔案:  ${swift_files} 個"
    echo "  Swift 行數:  ${swift_lines} 行"
    echo "  文檔檔案:    ${md_files} 個"
    echo ""
    
    echo "  模組列表:"
    echo "    • SmartIMECore   (核心引擎)"
    echo "    • SmartIMEApp    (macOS 輸入法)"
    echo "    • SmartIMEDemo   (示範程式)"
    echo "    • SmartIMECoreTests (單元測試)"
}

# ═══════════════════════════════════════════════
# 主選單
# ═══════════════════════════════════════════════
show_menu() {
    echo "請選擇操作："
    echo ""
    echo "  1) 建置全部 (Core + App)"
    echo "  2) 執行測試"
    echo "  3) 執行示範"
    echo "  4) 封裝 .app bundle"
    echo "  5) 安裝到系統"
    echo "  6) 專案統計"
    echo "  7) 清理"
    echo "  0) 退出"
    echo ""
    echo -n "輸入選項 [0-7]: "
}

# ═══════════════════════════════════════════════
# 入口
# ═══════════════════════════════════════════════

# 支援命令列參數直接執行
case "${1:-}" in
    build)
        show_banner
        check_env
        build_core
        build_app
        ;;
    test)
        show_banner
        check_env
        run_tests
        ;;
    demo)
        show_banner
        check_env
        run_demo
        ;;
    package)
        show_banner
        check_env
        package_app
        ;;
    install)
        show_banner
        check_env
        install_app
        ;;
    clean)
        show_banner
        clean
        ;;
    stats)
        show_banner
        stats
        ;;
    *)
        show_banner
        check_env
        echo ""
        
        # 互動模式
        while true; do
            show_menu
            read -r choice
            echo ""
            
            case $choice in
                1) build_core; build_app ;;
                2) run_tests ;;
                3) run_demo ;;
                4) package_app ;;
                5) install_app ;;
                6) stats ;;
                7) clean ;;
                0) print_info "再見！"; exit 0 ;;
                *) print_error "無效的選項" ;;
            esac
            
            echo ""
            echo "按 Enter 繼續..."
            read -r
            echo ""
        done
        ;;
esac

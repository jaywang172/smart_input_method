import Cocoa

/// 應用程式委託
/// 負責管理應用程式的生命週期
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private var inputMethodController: InputMethodController?
    private var statusItem: NSStatusItem?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 智能輸入法應用程式啟動")
        
        // 創建狀態列項目
        setupStatusBar()
        
        // 初始化輸入法控制器
        inputMethodController = InputMethodController()
        inputMethodController?.start()
        
        // 設置應用程式為背景運行
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("⏹️ 智能輸入法應用程式即將終止")
        inputMethodController?.stop()
    }
    
    // MARK: - Status Bar Setup
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "智能輸入法")
            } else {
                button.image = NSImage(named: "keyboard")
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        // 創建選單
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "切換輸入法", action: #selector(toggleInputMethod), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "設定", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func statusBarButtonClicked() {
        // 狀態列按鈕點擊處理
        print("🖱️ 狀態列按鈕被點擊")
    }
    
    @objc private func toggleInputMethod() {
        inputMethodController?.toggle()
        print("🔄 切換輸入法狀態")
    }
    
    @objc private func openSettings() {
        print("⚙️ 打開設定")
        // 這裡可以打開設定視窗
    }
    
    @objc private func quitApplication() {
        print("👋 退出應用程式")
        NSApp.terminate(nil)
    }
}

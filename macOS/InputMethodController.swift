import Cocoa
import Carbon

/// 輸入法控制器
/// 負責協調輸入法服務和候選詞視窗
class InputMethodController: NSObject {
    
    // MARK: - Properties
    
    private let inputMethodServer: InputMethodServer
    private var isActive = false
    
    // MARK: - Initialization
    
    override init() {
        self.inputMethodServer = InputMethodServer()
        super.init()
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(candidateSelected(_:)),
            name: .candidateSelected,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func start() {
        guard !isActive else { return }
        
        print("🚀 啟動智能輸入法控制器")
        inputMethodServer.start()
        isActive = true
    }
    
    func stop() {
        guard isActive else { return }
        
        print("⏹️ 停止智能輸入法控制器")
        inputMethodServer.stop()
        isActive = false
    }
    
    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func candidateSelected(_ notification: Notification) {
        guard let candidate = notification.userInfo?["candidate"] as? InputEngine.Candidate else { return }
        
        print("✅ 選擇候選詞: \(candidate.text)")
        
        // 這裡可以添加實際的文字插入邏輯
        insertText(candidate.text)
    }
    
    private func insertText(_ text: String) {
        // 使用 Accessibility API 插入文字
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 創建文字輸入事件
        for char in text.unicodeScalars {
            let keyCode = charToKeyCode(char)
            if keyCode != 0 {
                let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                
                keyDownEvent?.post(tap: .cghidEventTap)
                keyUpEvent?.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func charToKeyCode(_ char: UnicodeScalar) -> CGKeyCode {
        // 簡化的字符到鍵碼轉換
        let charValue = char.value
        
        switch charValue {
        case 0x20: return 49 // Space
        case 0x0A: return 36 // Return
        case 0x08: return 51 // Backspace
        case 0x1B: return 53 // Escape
        case 0x41...0x5A: return CGKeyCode(charValue - 0x41) // A-Z
        case 0x61...0x7A: return CGKeyCode(charValue - 0x61) // a-z
        case 0x30...0x39: return CGKeyCode(charValue - 0x30 + 18) // 0-9
        default:
            return 0
        }
    }
}

// MARK: - Application Delegate

extension InputMethodController: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("📱 應用程式啟動完成")
        start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("📱 應用程式即將終止")
        stop()
    }
}

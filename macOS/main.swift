import Cocoa

/// 智能輸入法主程式
/// 啟動 macOS 輸入法應用程式
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 啟動應用程式
app.run()

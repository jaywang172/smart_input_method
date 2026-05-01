import Cocoa
import InputMethodKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 全域變數方便存取
    var server: IMKServer?

    private func logToFile(_ message: String) {
        let path = "/tmp/smartime_boot.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path),
               let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logToFile("applicationDidFinishLaunching")
        // 1. 建立 IMKServer
        // connectionName 必須與 Info.plist 中的 InputMethodConnectionName 一致
        let kConnectionName = "SmartIME_Connection"
        
        server = IMKServer(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        logToFile("IMKServer initialized: \(kConnectionName)")
        
        NSLog("🚀 SmartIME started. Connection: \(kConnectionName)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logToFile("applicationWillTerminate")
        NSLog("🛑 SmartIME terminating...")
    }
}

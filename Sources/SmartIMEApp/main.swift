import Cocoa
import InputMethodKit

func appendBootLog(_ message: String) {
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

appendBootLog("main.swift start")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
appendBootLog("delegate assigned")
withExtendedLifetime(delegate) {
    appendBootLog("app.run enter")
    app.run()
}

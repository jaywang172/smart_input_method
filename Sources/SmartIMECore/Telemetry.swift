import Foundation

/// 簡易觀測：支援抽樣、事件統計與隱私友好欄位
final class Telemetry {
    static let shared = Telemetry()
    private init() {}

    struct Config {
        let enabled: Bool
        let sampleRate: Double   // 0.0 ~ 1.0
    }

    private var config = Config(enabled: false, sampleRate: 0.0)
    private let queue = DispatchQueue(label: "Telemetry")

    func updateConfig(_ newConfig: Config) { queue.sync { self.config = newConfig } }

    func sampled(_ block: () -> Void) {
        var cfg: Config = config
        queue.sync { cfg = self.config }
        guard cfg.enabled else { return }
        if Double.random(in: 0...1) <= cfg.sampleRate { block() }
    }

    func logEvent(_ name: String, fields: [String: Any]) {
        sampled {
            // 僅用於本地開發輸出；產品可替換為統計匯聚
            print("[Telemetry] \(name) -> \(fields)")
        }
    }
}

/// 簡易延遲量測工具
struct LatencyTimer {
    private let start: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    func endMillis() -> Double { (CFAbsoluteTimeGetCurrent() - start) * 1000.0 }
}



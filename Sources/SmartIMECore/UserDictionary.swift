import Foundation

/// 用戶詞庫：學習選字，提供頻率增益與持久化
class UserDictionary {
    private var counts: [String: Int] = [:]
    private var lastDecayAt: Date = Date()
    private let queue = DispatchQueue(label: "UserDictionary", attributes: .concurrent)
    private let maxEntries: Int

    init(maxEntries: Int = 10000) {
        self.maxEntries = maxEntries
    }

    func learn(_ word: String, delta: Int = 1) {
        queue.async(flags: .barrier) {
            self.counts[word, default: 0] += delta
            if self.counts.count > self.maxEntries {
                // 簡單的裁剪：移除最小頻率項
                if let minKey = self.counts.min(by: { $0.value < $1.value })?.key {
                    self.counts.removeValue(forKey: minKey)
                }
            }
        }
    }

    func frequency(of word: String) -> Int {
        var v = 0
        queue.sync { v = counts[word] ?? 0 }
        return v
    }

    func boostScore(for word: String, base: Double) -> Double {
        applyDecayIfNeeded()
        let f = Double(frequency(of: word))
        if f <= 0 { return base }
        // 次線性增益，避免學習後完全壓制 LM
        return base * (1.0 + log(1.0 + f) * 0.2)
    }

    /// 每日衰退（簡易），將所有頻次乘以 0.98，避免長期壘加
    private func applyDecayIfNeeded() {
        let now = Date()
        let calendar = Calendar.current
        if !calendar.isDate(lastDecayAt, inSameDayAs: now) {
            queue.async(flags: .barrier) {
                for (k, v) in self.counts { self.counts[k] = max(Int(Double(v) * 0.98), 0) }
                self.lastDecayAt = now
            }
        }
    }

    func save(to path: String) throws {
        let payload: [String: Any] = [
            "counts": counts,
            "lastDecayAt": ISO8601DateFormatter().string(from: lastDecayAt)
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        try data.write(to: URL(fileURLWithPath: path))
    }

    func load(from path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let countsLoaded = json["counts"] as? [String: Int] ?? [:]
            let lastDecayStr = json["lastDecayAt"] as? String
            let lastDecay = lastDecayStr.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            queue.async(flags: .barrier) {
                self.counts = countsLoaded
                self.lastDecayAt = lastDecay
            }
        }
    }
}



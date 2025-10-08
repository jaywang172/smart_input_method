import Foundation

/// 效能儀表板：彙總指標、SLA 門檻與告警
final class PerformanceDashboard {
    static let shared = PerformanceDashboard()
    private init() {}
    
    struct Metrics {
        var latencyP50: Double = 0.0
        var latencyP95: Double = 0.0
        var latencyP99: Double = 0.0
        var qps: Double = 0.0
        var candidateHitRate: Double = 0.0
        var resourceLoadTime: Double = 0.0
        var memoryUsage: Double = 0.0
    }
    
    struct SLAThresholds {
        let maxLatencyP95: Double = 2.0  // ms
        let minQPS: Double = 100.0
        let minHitRate: Double = 0.8
        let maxResourceLoadTime: Double = 100.0  // ms
        let maxMemoryUsage: Double = 100.0  // MB
    }
    
    private var metrics = Metrics()
    private let thresholds = SLAThresholds()
    private let queue = DispatchQueue(label: "PerformanceDashboard", attributes: .concurrent)
    private var samples: [Double] = []
    private let maxSamples = 1000
    
    /// 記錄延遲樣本
    func recordLatency(_ ms: Double) {
        queue.async(flags: .barrier) {
            self.samples.append(ms)
            if self.samples.count > self.maxSamples {
                self.samples.removeFirst()
            }
            self.updateLatencyMetrics()
        }
    }
    
    /// 記錄候選命中
    func recordCandidateHit(_ hit: Bool) {
        queue.async(flags: .barrier) {
            // 簡化：假設有命中率追蹤
            self.metrics.candidateHitRate = hit ? 1.0 : 0.0
        }
    }
    
    /// 記錄資源載入時間
    func recordResourceLoadTime(_ ms: Double) {
        queue.async(flags: .barrier) {
            self.metrics.resourceLoadTime = ms
        }
    }
    
    /// 更新延遲指標
    private func updateLatencyMetrics() {
        guard !samples.isEmpty else { return }
        let sorted = samples.sorted()
        let count = sorted.count
        
        metrics.latencyP50 = sorted[Int(Double(count) * 0.5)]
        metrics.latencyP95 = sorted[Int(Double(count) * 0.95)]
        metrics.latencyP99 = sorted[Int(Double(count) * 0.99)]
        
        // 簡化 QPS 計算
        metrics.qps = 1000.0 / max(metrics.latencyP50, 0.1)
    }
    
    /// 檢查 SLA 違約
    func checkSLAViolations() -> [String] {
        var violations: [String] = []
        
        if metrics.latencyP95 > thresholds.maxLatencyP95 {
            violations.append("P95 latency exceeded: \(String(format: "%.2f", metrics.latencyP95))ms > \(thresholds.maxLatencyP95)ms")
        }
        
        if metrics.qps < thresholds.minQPS {
            violations.append("QPS below threshold: \(String(format: "%.1f", metrics.qps)) < \(thresholds.minQPS)")
        }
        
        if metrics.candidateHitRate < thresholds.minHitRate {
            violations.append("Hit rate below threshold: \(String(format: "%.2f", metrics.candidateHitRate)) < \(thresholds.minHitRate)")
        }
        
        if metrics.resourceLoadTime > thresholds.maxResourceLoadTime {
            violations.append("Resource load time exceeded: \(String(format: "%.1f", metrics.resourceLoadTime))ms > \(thresholds.maxResourceLoadTime)ms")
        }
        
        return violations
    }
    
    /// 獲取當前指標
    func getMetrics() -> Metrics {
        var result = Metrics()
        queue.sync { result = self.metrics }
        return result
    }
    
    /// 生成報告
    func generateReport() -> String {
        let m = getMetrics()
        let violations = checkSLAViolations()
        
        var report = "=== Performance Dashboard ===\n"
        report += "P50 Latency: \(String(format: "%.2f", m.latencyP50))ms\n"
        report += "P95 Latency: \(String(format: "%.2f", m.latencyP95))ms\n"
        report += "P99 Latency: \(String(format: "%.2f", m.latencyP99))ms\n"
        report += "QPS: \(String(format: "%.1f", m.qps))\n"
        report += "Hit Rate: \(String(format: "%.2f", m.candidateHitRate))\n"
        report += "Resource Load: \(String(format: "%.1f", m.resourceLoadTime))ms\n"
        
        if !violations.isEmpty {
            report += "\n⚠️ SLA Violations:\n"
            for violation in violations {
                report += "- \(violation)\n"
            }
        } else {
            report += "\n✅ All SLA thresholds met\n"
        }
        
        return report
    }
}

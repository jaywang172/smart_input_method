import Foundation

/// 基準測試：量測 handleInput 延遲與 QPS 粗估
class Benchmarks {
    func run() {
        print("\n==== 基準測試 ====")
        Telemetry.shared.updateConfig(Telemetry.Config(enabled: true, sampleRate: 1.0))
        let engine = InputEngine(config: InputEngineConfig(lazyLoadResources: true))
        let samples = ["n", "i", "h", "a", "o", " ", "s", "w", "i", "f", "t"]
        let loops = 100
        var counts = 0

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<loops {
            engine.reset()
            for ch in samples { _ = engine.handleInput(ch); counts += 1 }
        }
        let end = CFAbsoluteTimeGetCurrent()
        let totalMs = (end - start) * 1000.0
        let avgPerOpMs = totalMs / Double(counts)
        print(String(format: "總操作: %d, 總耗時: %.1f ms, 平均每次: %.3f ms", counts, totalMs, avgPerOpMs))
        print("基準測試完成 ✅\n")
    }
}

Benchmarks().run()



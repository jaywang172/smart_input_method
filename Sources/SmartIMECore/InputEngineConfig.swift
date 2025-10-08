import Foundation

/// 輸入引擎初始化與行為配置
struct InputEngineConfig {
    /// 是否延遲載入大型資源（詞典/模型）。true 則在需要時再載入。
    let lazyLoadResources: Bool
    /// 候選詞最大數量上限
    let maxCandidates: Int
    /// 預留：是否啟用非阻塞/串流候選
    let enableAsync: Bool
    /// 外部資源路徑（可選），例如詞典與模型路徑
    let resourcePaths: [String: String]?

    init(lazyLoadResources: Bool = false,
         maxCandidates: Int = 10,
         enableAsync: Bool = false,
         resourcePaths: [String: String]? = nil) {
        self.lazyLoadResources = lazyLoadResources
        self.maxCandidates = maxCandidates
        self.enableAsync = enableAsync
        self.resourcePaths = resourcePaths
    }

    /// 預設配置（保持與既有行為一致）
    static let `default` = InputEngineConfig(
        lazyLoadResources: false,
        maxCandidates: 10,
        enableAsync: false,
        resourcePaths: nil
    )
}




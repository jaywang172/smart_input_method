import Foundation

/// 資源清單：描述模型/詞典版本與路徑，支援回滾
struct ResourceManifest: Codable {
    let version: String
    let createdAt: String
    let description: String?
    let resources: [String: String]   // 鍵同 InputEngineConfig.resourcePaths 的鍵
    let rollbackManifestPath: String?
}

enum ResourceLoadError: Error {
    case fileMissing(String)
    case manifestInvalid(String)
}

final class VersionedResourceLoader {
    static func loadManifest(at path: String) throws -> ResourceManifest {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let manifest = try JSONDecoder().decode(ResourceManifest.self, from: data)
        return manifest
    }

    /// 驗證資源是否存在，失敗時丟出錯誤
    private static func validateResources(_ resources: [String: String]) throws {
        for (key, p) in resources {
            if !FileManager.default.fileExists(atPath: p) {
                throw ResourceLoadError.fileMissing("\(key) -> \(p)")
            }
        }
    }

    /// 載入清單並驗證，若失敗嘗試回滾清單
    static func resolvePathsWithRollback(manifestPath: String) throws -> (manifest: ResourceManifest, paths: [String: String], rolledBack: Bool) {
        do {
            let m = try loadManifest(at: manifestPath)
            try validateResources(m.resources)
            return (m, m.resources, false)
        } catch {
            // 嘗試回滾
            let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
            guard let m = try? JSONDecoder().decode(ResourceManifest.self, from: data),
                  let rollback = m.rollbackManifestPath else {
                throw error
            }
            let rm = try loadManifest(at: rollback)
            try validateResources(rm.resources)
            return (rm, rm.resources, true)
        }
    }
}



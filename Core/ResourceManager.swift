import Foundation

/// 資源管理：支援記憶體映射讀取大型檔案與通用解析
enum ResourceManager {
    /// 安全地以記憶體映射方式讀取文字檔
    static func mappedString(at path: String, encoding: String.Encoding = .utf8) throws -> String {
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let str = String(data: data, encoding: encoding) else {
                throw NSError(domain: "ResourceManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Encoding failed for file: \(path)"])
            }
            return str
        } catch {
            Telemetry.shared.logEvent("resource_read_error", fields: ["path": path])
            throw error
        }
    }

    /// 詞頻檔解析：每行「詞[空白]頻率」，忽略空行與註解（以#開頭）
    static func loadWordFrequencies(at path: String) throws -> [(String, Int)] {
        let content = try mappedString(at: path)
        var result: [(String, Int)] = []
        result.reserveCapacity(1024)
        for line in content.split(whereSeparator: { $0.isNewline }) {
            if line.isEmpty { continue }
            if line.first == "#" { continue }
            let parts = line.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            guard let first = parts.first else { continue }
            let word = String(first)
            let freq = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
            result.append((word, max(freq, 1)))
        }
        return result
    }

    /// 注音詞典解析：每行格式「中文\t注音」
    static func loadBopomofoDictionary(at path: String) throws -> [(chinese: String, bopomofo: String)] {
        let content = try mappedString(at: path)
        var result: [(String, String)] = []
        result.reserveCapacity(1024)
        for line in content.split(whereSeparator: { $0.isNewline }) {
            if line.isEmpty { continue }
            if line.first == "#" { continue }
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            result.append((String(parts[0]), String(parts[1])))
        }
        return result
    }

    static func fileExists(_ path: String?) -> Bool {
        guard let p = path else { return false }
        return FileManager.default.fileExists(atPath: p)
    }
}



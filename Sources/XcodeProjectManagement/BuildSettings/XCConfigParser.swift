import Foundation

enum XCConfigParser {
    static func parse(at path: String) throws -> [String: String] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var settings: [String: String] = [:]

        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 忽略注释和空行
            guard !trimmed.isEmpty, !trimmed.hasPrefix("//"), !trimmed.hasPrefix("/*") else {
                continue
            }

            if trimmed.hasPrefix("#include") {
                // 处理 include
                // 例子: #include "Base.xcconfig"
                if let start = trimmed.firstIndex(of: "\""),
                   let end = trimmed.lastIndex(of: "\""), start < end {
                    let includePath = String(trimmed[trimmed.index(after: start) ..< end])
                    let includeFullPath = ((path as NSString).deletingLastPathComponent as NSString)
                        .appendingPathComponent(includePath)
                    let included = try parse(at: includeFullPath)
                    // 上层文件覆盖下层 include
                    settings.merge(included) { current, _ in current }
                }
            } else if let eqIndex = trimmed.firstIndex(of: "=") {
                let key = trimmed[..<eqIndex].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)
                settings[key] = value
            }
        }
        return settings
    }
}

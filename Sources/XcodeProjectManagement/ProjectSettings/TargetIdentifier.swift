import Foundation

struct TargetIdentifier: Hashable, Sendable, Codable, RawRepresentable {
    var rawValue: String

    let projectFilePath: String
    let targetName: String

    init(projectFilePath: String, targetName: String) {
        self.projectFilePath = projectFilePath
        self.targetName = targetName
        self.rawValue = "xcode://\(projectFilePath)/\(targetName)"
    }

    init(rawValue: String) {
        // xcode:///path/to/project.xcodeproj/TargetName
        let prefix = "xcode://"
        var trimmed = rawValue
        if trimmed.hasPrefix(prefix) {
            trimmed.removeFirst(prefix.count)
        }
        if trimmed.hasPrefix("/") {
            trimmed.removeFirst()
        }
        let components = trimmed.split(separator: "/")
        self.projectFilePath = "/" + components.dropLast().joined(separator: "/")
        self.targetName = String(components.last ?? "")

        self.rawValue = rawValue
    }

    var projectFolderURL: URL {
        URL(fileURLWithPath: projectFilePath).deletingLastPathComponent()
    }
}

import Foundation

public struct TargetIdentifier: Hashable, Sendable, Codable, RawRepresentable {
    public var rawValue: String

    public let projectFilePath: String
    public let targetName: String

    public init(projectFilePath: String, targetName: String) {
        self.projectFilePath = projectFilePath
        self.targetName = targetName
        self.rawValue = "xcode://\(projectFilePath)/\(targetName)"
    }

    public init(rawValue: String) {
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

    public var projectFolderURL: URL {
        URL(fileURLWithPath: projectFilePath).deletingLastPathComponent()
    }
}

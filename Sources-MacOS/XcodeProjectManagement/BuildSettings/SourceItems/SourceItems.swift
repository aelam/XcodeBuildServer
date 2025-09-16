import Foundation

public struct SourceItem: Codable, Hashable, Sendable {
    public enum SourceItemKind: Int, Codable, Hashable, Sendable {
        case file = 1
        case directory = 2
    }

    public let path: URL
    public let itemKind: SourceItemKind
}

public struct SourcesItem: Codable, Hashable, Sendable {
    public var target: XcodeTargetIdentifier

    /// The text documents and directories that belong to this build target.
    public var sources: [SourceItem]

    /// The root directories from where source files should be relativized.
    /// Example: ["file://Users/name/dev/metals/src/main/scala"]
    public var roots: [URL]?

    public init(target: XcodeTargetIdentifier, sources: [SourceItem], roots: [URL]? = nil) {
        self.target = target
        self.sources = sources
        self.roots = roots
    }
}

import Foundation

/// Target information with complete project context
public struct XcodeTarget: Sendable, Hashable, Codable {
    public enum Platform: String, Sendable, Codable, Hashable {
        case iOS = "iphoneos"
        case macOS = "macosx"
        case tvOS = "appletvos"
        case watchOS = "watchos"
        case visionOS = "visionos"

        func sdk(simulator: Bool) -> XcodeSDK {
            switch self {
            case .iOS: simulator ? .iOSSimulator : .iOS
            case .macOS: .macOS
            case .tvOS: simulator ? .tvOSSimulator : .tvOS
            case .watchOS: simulator ? .watchOSSimulator : .watchOS
            case .visionOS: simulator ? .visionOSSimulator : .visionOS
            }
        }
    }

    public let name: String
    public let projectURL: URL
    public let projectName: String
    public let isFromWorkspace: Bool
    public let buildForTesting: Bool
    public let buildForRunning: Bool
    public let platform: Platform

    // Computed property for legacy compatibility
    public var targetName: String { name }

    public init(
        name: String,
        projectURL: URL,
        isFromWorkspace: Bool = false,
        buildForTesting: Bool = true,
        buildForRunning: Bool = true,
        platform: Platform = .iOS
    ) {
        self.name = name
        self.projectURL = projectURL
        self.projectName = projectURL.deletingPathExtension().lastPathComponent
        self.isFromWorkspace = isFromWorkspace
        self.buildForTesting = buildForTesting
        self.buildForRunning = buildForRunning
        self.platform = platform
    }

    public var debugDescription: String {
        "XcodeTarget(name: \(name), " +
            "projectURL: \(projectURL.path), " +
            "isFromWorkspace: \(isFromWorkspace), " +
            "platform: \(platform.rawValue))"
    }
}

public typealias XcodeSchemeTargetInfo = XcodeTarget

public struct GroupedTargetsKey: Hashable, Sendable {
    let projectURL: URL
    let platform: XcodeTarget.Platform
}

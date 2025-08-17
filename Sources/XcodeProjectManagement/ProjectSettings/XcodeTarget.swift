import Foundation
import XcodeProj

/// Target information with complete project context
public struct XcodeTarget: Sendable, Hashable, Codable {
    public enum Platform: String, Sendable, Codable, Hashable {
        case iOS = "iphoneos"
        case macOS = "macosx"
        case tvOS = "appletvos"
        case watchOS = "watchos"
        case visionOS = "xros"

        // "AVAILABLE_PLATFORMS" : "android appletvos appletvsimulator driverkit iphoneos iphonesimulator macosx qnx
        // watchos watchsimulator xros xrsimulator",

        func sdk(simulator: Bool) -> XcodeSDK {
            switch self {
            case .iOS: simulator ? .iOSSimulator : .iOS
            case .macOS: .macOS
            case .tvOS: simulator ? .tvSimulator : .tvOS
            case .watchOS: simulator ? .watchSimulator : .watchOS
            case .visionOS: simulator ? .visionSimulator : .visionOS
            }
        }
    }

    public typealias ProductType = XcodeProductType

    public let name: String
    public let projectURL: URL
    public let projectName: String
    public let productName: String?
    public let isFromWorkspace: Bool
    public let buildForTesting: Bool
    public let buildForRunning: Bool
    public let platform: Platform
    public let productType: XcodeProductType

    public var productNameWithExtension: String? {
        guard
            let productName,
            let fileExtension = productType.fileExtension
        else {
            return productName
        }
        return productName + "." + fileExtension
    }

    // Computed property for legacy compatibility
    public var targetName: String { name }

    public init(
        name: String,
        projectURL: URL,
        productName: String?,
        isFromWorkspace: Bool = false,
        buildForTesting: Bool = true,
        buildForRunning: Bool = true,
        platform: Platform = .iOS,
        productType: ProductType
    ) {
        self.name = name
        self.projectURL = projectURL
        self.projectName = projectURL.deletingPathExtension().lastPathComponent
        self.productName = productName
        self.isFromWorkspace = isFromWorkspace
        self.buildForTesting = buildForTesting
        self.buildForRunning = buildForRunning
        self.platform = platform
        self.productType = productType
    }

    public var debugDescription: String {
        "XcodeTarget(name: \(name), " +
            "projectURL: \(projectURL.path), " +
            "isFromWorkspace: \(isFromWorkspace), " +
            "platform: \(platform.rawValue))"
    }

    var priority: Double {
        let productTypeWeight = switch productType {
        case .application, .commandLineTool: 1.0
        case .watchApp, .watch2App, .watch2AppContainer, .messagesApplication: 0.9
        case .appExtension, .watchExtension, .watch2Extension, .tvExtension: 0.8
        case .framework, .staticLibrary, .dynamicLibrary, .staticFramework: 0.7
        case .bundle: 0.5
        default: 0.0
        }

        let platformWeight = switch platform {
        case .iOS: 1.0
        case .macOS: 0.8
        case .watchOS: 0.5
        case .tvOS: 0.4
        case .visionOS: 0.3
        }

        let runningBonus: Double = buildForRunning ? 0.1 : 0.0
        return platformWeight * productTypeWeight + runningBonus
    }
}

public typealias XcodeSchemeTargetInfo = XcodeTarget

public struct GroupedTargetsKey: Hashable, Sendable {
    let projectURL: URL
    let platform: XcodeTarget.Platform
}

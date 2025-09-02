public enum XcodeSDK: String, Sendable {
    case macOS = "macosx"
    case iOS = "iphoneos"
    case iOSSimulator = "iphonesimulator"
    case watchOS = "watchos"
    case watchSimulator = "watchsimulator"
    case tvOS = "appletvos"
    case tvSimulator = "appletvsimulator"
    case visionOS = "xros"
    case visionSimulator = "xrsimulator"
}

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

public struct SDK {
    public enum Platform: String, Sendable {
        case iOS = "iphoneos"
        case iOSSimulator = "iphonesimulator"
        case macOS = "macosx"
        case watchOS = "watchos"
        case watchOSSimulator = "watchsimulator"
        case tvOS = "tvos"
        case tvOSSimulator = "tvossimulator"

        init(platformPathName: String) {
            switch platformPathName {
            case "iPhoneOS": self = .iOS
            case "iPhoneSimulator": self = .iOSSimulator
            case "MacOS": self = .macOS
            case "watchOS": self = .watchOS
            case "watchOSSimulator": self = .watchOSSimulator
            case "tvOS": self = .tvOS
            case "tvOSSimulator": self = .tvOSSimulator
            default: self = .iOSSimulator // 默认值
            }
        }

        var platformPathName: String {
            switch self {
            case .iOS: "iPhoneOS"
            case .iOSSimulator: "iPhoneSimulator"
            case .macOS: "MacOSX"
            case .watchOS: "WatchOS"
            case .watchOSSimulator: "WatchOSSimulator"
            case .tvOS: "AppleTVOS"
            case .tvOSSimulator: "AppleTVSimulator"
            }
        }

        var buildSettingsKey: String {
            switch self {
            case .iOS: "IPHONEOS_DEPLOYMENT_TARGET"
            case .iOSSimulator: "IPHONEOS_DEPLOYMENT_TARGET"
            case .macOS: "MACOSX_DEPLOYMENT_TARGET"
            case .watchOS: "WATCHOS_DEPLOYMENT_TARGET"
            case .watchOSSimulator: "WATCHOS_DEPLOYMENT_TARGET"
            case .tvOS: "TVOS_DEPLOYMENT_TARGET"
            case .tvOSSimulator: "TVOS_DEPLOYMENT_TARGET"
            }
        }
    }

    let name: String
    let version: String
    let path: String
    let buildVersion: String
}

import Foundation

public enum XcodeDestinationPlatform: String, Sendable, Codable, CaseIterable {
    case iOS
    case macOS
    case watchOS
    case tvOS
    case visionOS
}

public enum XcodeDestinationType: String, Sendable, Codable {
    case simulator = "Simulator"
    case device = "Device"
}

public enum XcodeDestinationArchitecture: String, Sendable, Codable, CaseIterable {
    case arm64
    case x86_64 // swiftlint:disable:this identifier_name

    var displayName: String {
        switch self {
        case .arm64:
            "Apple Silicon"
        case .x86_64:
            "Intel 64-bit"
        }
    }
}

public struct XcodePairedDevice: Codable, Sendable, Hashable {
    public let name: String
    public let platform: XcodeDestinationPlatform
    public let version: String?

    init(name: String, platform: XcodeDestinationPlatform, version: String? = nil) {
        self.name = name
        self.platform = platform
        self.version = version
    }

    public var displayName: String {
        if let version {
            return "\(name) (\(version))"
        }
        return name
    }
}

public struct XcodeDestination: Sendable, Codable, Hashable {
    public let name: String
    public let id: String
    public let platform: XcodeDestinationPlatform
    public let type: XcodeDestinationType
    public let version: String?
    public let architectures: [XcodeDestinationArchitecture]
    public let isAvailable: Bool
    public let isRunnable: Bool
    public let pairedDevice: XcodePairedDevice?

    // iPhone + Apple Watch
    var supportedPlatforms: [XcodeDestinationPlatform] {
        var platforms = [platform]
        if let paired = pairedDevice {
            platforms.append(paired.platform)
        }
        return platforms
    }

    public init(
        name: String,
        id: String,
        platform: XcodeDestinationPlatform,
        type: XcodeDestinationType,
        version: String? = nil,
        architectures: [XcodeDestinationArchitecture] = [.arm64, .x86_64],
        isAvailable: Bool = true,
        isRunnable: Bool = true,
        pairedDevice: XcodePairedDevice? = nil
    ) {
        self.name = name
        self.id = id
        self.platform = platform
        self.type = type
        self.version = version
        self.architectures = architectures
        self.isAvailable = isAvailable
        self.isRunnable = isRunnable
        self.pairedDevice = pairedDevice
    }

    public var displayName: String {
        let baseName = switch type {
        case .simulator:
            "\(name)"
        case .device:
            platform == .macOS ? "My Mac" : name
        }

        if let paired = pairedDevice {
            return "\(baseName) + \(paired.displayName)"
        }

        return baseName
    }

    public var fullDescription: String {
        var components = [displayName]
        if let version {
            components.append("(\(version))")
        }
        return components.joined(separator: " ")
    }

    static func macDestination() -> XcodeDestination? {
        // Get actual Mac device ID from xctrace
        let process = Process()
        process.launchPath = "/usr/bin/xcrun"
        process.arguments = ["xctrace", "list", "devices"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse the first device line which should be the Mac
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if !trimmedLine.isEmpty,
               !trimmedLine.starts(with: "=="),
               trimmedLine.contains("("), trimmedLine.contains(")") {
                // Parse: "DeviceName (UUID)"
                if let openParen = trimmedLine.lastIndex(of: "("),
                   let closeParen = trimmedLine.lastIndex(of: ")") {
                    let deviceName = String(trimmedLine[..<openParen]).trimmingCharacters(in: .whitespaces)
                    let deviceId = String(trimmedLine[trimmedLine.index(after: openParen) ..< closeParen])

                    return XcodeDestination(
                        name: deviceName.isEmpty ? "My Mac" : deviceName,
                        id: deviceId,
                        platform: .macOS,
                        type: .device,
                        architectures: [.arm64]
                    )
                }
            }
        }

        // Fallback if parsing fails
        return XcodeDestination(
            name: "My Mac",
            id: "mac",
            platform: .macOS,
            type: .device,
            architectures: [.arm64]
        )
    }

    static func anyMac() -> XcodeDestination {
        XcodeDestination(
            name: "Any Mac",
            id: "generic/platform=macOS",
            platform: .macOS,
            type: .device,
            isRunnable: false
        )
    }

    static let anyiOSDevice = XcodeDestination(
        name: "iOS Device",
        id: "generic/platform=iOS",
        platform: .iOS,
        type: .device,
        isRunnable: false
    )

    static let anyiOSSimulator = XcodeDestination(
        name: "iOS Simulator",
        id: "generic/platform=iOS Simulator",
        platform: .iOS,
        type: .simulator,
        isRunnable: false
    )

    static let anyTVOSDevice = XcodeDestination(
        name: "tvOS Device",
        id: "generic/platform=tvOS",
        platform: .tvOS,
        type: .device,
        isRunnable: false
    )

    static let anyTVOSSimulator = XcodeDestination(
        name: "tvOS Simulator",
        id: "generic/platform=tvOS Simulator",
        platform: .tvOS,
        type: .simulator,
        isRunnable: false
    )

    static let anyWatchOSDevice = XcodeDestination(
        name: "watchOS Device",
        id: "generic/platform=watchOS",
        platform: .watchOS,
        type: .device,
        isRunnable: false
    )

    static let anyWatchOSSimulator = XcodeDestination(
        name: "watchOS Simulator",
        id: "generic/platform=watchOS Simulator",
        platform: .watchOS,
        type: .simulator,
        isRunnable: false
    )

    static let anyVisionOSDevice = XcodeDestination(
        name: "visionOS Device",
        id: "generic/platform=visionOS",
        platform: .visionOS,
        type: .device,
        isRunnable: false
    )

    static let anyVisionOSSimulator = XcodeDestination(
        name: "visionOS Simulator",
        id: "generic/platform=visionOS Simulator",
        platform: .visionOS,
        type: .simulator,
        isRunnable: false
    )
}

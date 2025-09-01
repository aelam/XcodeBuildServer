//
//  XcodeToolchain.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public enum XcodeToolchainError: Error, LocalizedError {
    case xcodeNotFound
    case xcodeVersionNotSupported(String)
    case xcodebuildNotFound
    case invalidDeveloperDir(String)
    case toolchainSelectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .xcodeNotFound:
            "No Xcode installation found"
        case let .xcodeVersionNotSupported(version):
            "Xcode version \(version) is not supported"
        case .xcodebuildNotFound:
            "xcodebuild tool not found"
        case let .invalidDeveloperDir(path):
            "Invalid DEVELOPER_DIR: \(path)"
        case let .toolchainSelectionFailed(reason):
            "Failed to select toolchain: \(reason)"
        }
    }
}

public struct XcodeInstallation: Sendable, Codable {
    public let path: URL
    public let version: String
    public let buildVersion: String
    public let isDeveloperDirSet: Bool

    public var developerDir: URL {
        path.appendingPathComponent("Contents/Developer")
    }

    public var xcodebuildPath: URL {
        developerDir.appendingPathComponent("usr/bin/xcodebuild")
    }

    public var isValid: Bool {
        FileManager.default.fileExists(atPath: xcodebuildPath.path)
    }
}

public extension XcodeInstallation {
    struct SDK {
        enum Platform: String, Sendable {
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

    func defaultDeploymentTarget(
        for platformName: String,
        forSimulator: Bool = false
    ) -> SDK? {
        let platform = SDK.Platform(rawValue: platformName) ?? .iOSSimulator

        let sdkDir = developerDir
            .appendingPathComponent("Platforms")
            .appendingPathComponent(
                "\(platform.platformPathName).platform/Developer/SDKs"
            )

        guard
            let contents = try? FileManager.default
            .contentsOfDirectory(atPath: sdkDir.path)
        else {
            return nil
        }
        let sdkNames = contents.filter { $0.hasSuffix(".sdk") }
            .sorted { $0 > $1 }
        guard let sdkName = sdkNames.first else {
            return nil
        }
        // 例: "iPhoneOS18.5.sdk" → 提取 18.5 → 返回 "18.0"
        let versionString = sdkName.replacingOccurrences(
            of: "\(platform.platformPathName)",
            with: ""
        )
        .replacingOccurrences(of: ".sdk", with: "")
        .replacingOccurrences(of: "OS", with: "") // AppleTVOS/WatchOS 处理
        .replacingOccurrences(of: "Simulator", with: "")
        let sdkPath = sdkDir.appendingPathComponent(sdkName).path

        let plistPath = sdkPath + "/System/Library/CoreServices/SystemVersion.plist"

        var buildVersion: String?
        if let dict = NSDictionary(contentsOfFile: plistPath) {
            buildVersion = dict["ProductBuildVersion"] as? String
        }

        return SDK(
            name: platformName,
            version: versionString,
            path: sdkPath,
            buildVersion: buildVersion ?? "Unknown"
        )
    }
}

public struct XcodeBuildResult: Sendable {
    public let output: String
    public let error: String?
    public let exitCode: Int32
}

public actor XcodeToolchain {
    private var selectedInstallation: XcodeInstallation?
    private var availableInstallations: [XcodeInstallation] = []
    private let preferredVersion: String?
    private let customDeveloperDir: String?
    private let processExecutor = ProcessExecutor()
    private let commonXcodePaths = [
        "/Applications/Xcode.app",
        "/Applications/Xcode-beta.app"
    ]

    public init(
        preferredVersion: String? = nil,
        customDeveloperDir: String? = nil
    ) {
        self.preferredVersion = preferredVersion
        self.customDeveloperDir = customDeveloperDir
    }

    deinit {
        // Clean up any remaining resources
        selectedInstallation = nil
        availableInstallations.removeAll()
    }

    public func initialize() async throws {
        guard selectedInstallation == nil else {
            return
        }
        try await discoverXcodeInstallations()
        try await selectBestInstallation()
    }

    public func getSelectedInstallation() -> XcodeInstallation? {
        selectedInstallation
    }

    public func executeXcodeBuild(
        arguments: [String],
        workingDirectory: URL? = nil
    ) async throws -> XcodeBuildResult {
        guard let installation = selectedInstallation else {
            throw XcodeToolchainError.xcodeNotFound
        }

        let result = try await processExecutor.executeXcodeBuild(
            arguments: arguments,
            workingDirectory: workingDirectory,
            xcodeInstallationPath: installation.path
        )

        return XcodeBuildResult(
            output: result.output,
            error: result.error,
            exitCode: result.exitCode
        )
    }

    public func getXcodeVersion() async throws -> String {
        guard selectedInstallation != nil else {
            throw XcodeToolchainError.xcodeNotFound
        }

        let result = try await executeXcodeBuild(arguments: ["-version"])
        guard result.exitCode == 0 else {
            let errorMessage = result.error ?? "xcodebuild -version failed"
            throw XcodeToolchainError.toolchainSelectionFailed(errorMessage)
        }

        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func isXcodeBuildAvailable() async -> Bool {
        guard let installation = selectedInstallation else {
            return false
        }

        return installation.isValid
    }

    // MARK: - Private Methods

    private func discoverXcodeInstallations() async throws {
        var installations: [XcodeInstallation] = []

        installations += await findDeveloperDirInstallations()
        installations += await findActiveXcodeInstallations()
        installations += await findCommonPathInstallations()
        installations += await findAdditionalXcodeVersions()

        self.availableInstallations = deduplicateInstallations(installations)
    }

    private func selectBestInstallation() async throws {
        guard !availableInstallations.isEmpty else {
            throw XcodeToolchainError.xcodeNotFound
        }

        // 1. Prefer DEVELOPER_DIR set installation
        if let developerDirInstallation = availableInstallations
            .first(where: { $0.isDeveloperDirSet }) {
            selectedInstallation = developerDirInstallation
            return
        }

        // 2. Prefer specific version if requested
        if let preferredVersion {
            if let preferredInstallation = availableInstallations
                .first(where: { $0.version.contains(preferredVersion) }) {
                selectedInstallation = preferredInstallation
                return
            }
        }

        // 3. Use the latest available version
        selectedInstallation = availableInstallations.first
    }

    private func createInstallation(
        from xcodeURL: URL,
        isDeveloperDirSet: Bool
    ) async throws -> XcodeInstallation {
        try XcodeInstallationFactory.createInstallation(
            from: xcodeURL,
            isDeveloperDirSet: isDeveloperDirSet
        )
    }

    private func findActiveXcodePath() async throws -> String? {
        try await XcodePathResolver.findActiveXcodePath()
    }

    private func findDeveloperDirInstallations() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []

        // Check DEVELOPER_DIR environment variable
        if let customDir = customDeveloperDir ?? ProcessInfo.processInfo
            .environment["DEVELOPER_DIR"] {
            let developerDirURL = URL(fileURLWithPath: customDir)
            let xcodeURL = developerDirURL.deletingLastPathComponent()
                .deletingLastPathComponent()

            if let installation = try? await createInstallation(
                from: xcodeURL,
                isDeveloperDirSet: true
            ) {
                installations.append(installation)
            }
        }

        // Check current xcode-select --print-path
        if let currentDeveloperDir = try? await XcodePathResolver
            .getCurrentDeveloperDir() {
            let developerDirURL = URL(fileURLWithPath: currentDeveloperDir)
            let xcodeURL = developerDirURL.deletingLastPathComponent()
                .deletingLastPathComponent()

            let alreadyFound = installations
                .contains { $0.path.path == xcodeURL.path }
            if !alreadyFound, let installation = try? await createInstallation(
                from: xcodeURL,
                isDeveloperDirSet: false
            ) {
                installations.append(installation)
            }
        }

        return installations
    }

    private func findActiveXcodeInstallations() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []

        if let activeXcode = try? await findActiveXcodePath() {
            let xcodeURL = URL(fileURLWithPath: activeXcode)
            if let installation = try? await createInstallation(
                from: xcodeURL,
                isDeveloperDirSet: false
            ) {
                installations.append(installation)
            }
        }

        return installations
    }

    private func findCommonPathInstallations() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []
        for path in commonXcodePaths {
            let xcodeURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: xcodeURL.path),
               let installation = try? await createInstallation(
                   from: xcodeURL,
                   isDeveloperDirSet: false
               ) {
                installations.append(installation)
            }
        }

        return installations
    }

    private func findAdditionalXcodeVersions() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []

        if let applicationsContents = try? FileManager.default
            .contentsOfDirectory(atPath: "/Applications") {
            for item in applicationsContents {
                if item.hasPrefix("Xcode"), item.hasSuffix(".app"),
                   !commonXcodePaths.contains("/Applications/\(item)") {
                    let xcodeURL = URL(fileURLWithPath: "/Applications/\(item)")
                    if let installation = try? await createInstallation(
                        from: xcodeURL,
                        isDeveloperDirSet: false
                    ) {
                        installations.append(installation)
                    }
                }
            }
        }

        return installations
    }

    private func deduplicateInstallations(_ installations: [XcodeInstallation])
        -> [XcodeInstallation] {
        let uniqueInstallations = installations
            .reduce(into: [String: XcodeInstallation]()) { dict, installation in
                let path = installation.path.path
                if let existing = dict[path] {
                    dict[path] = installation
                        .isDeveloperDirSet ? installation : existing
                } else {
                    dict[path] = installation
                }
            }.values

        return Array(uniqueInstallations).sorted { $0.version > $1.version }
    }
}

// MARK: - Utility Functions

public func isXcodeBuildAvailable() async -> Bool {
    let toolchain = XcodeToolchain()
    do {
        try await toolchain.initialize()
        return await toolchain.isXcodeBuildAvailable()
    } catch {
        return false
    }
}

// MARK: - Helper Classes

private enum XcodeInstallationFactory {
    static func createInstallation(
        from xcodeURL: URL,
        isDeveloperDirSet: Bool
    ) throws -> XcodeInstallation {
        let infoPlistURL = xcodeURL
            .appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData,
                  format: nil
              ) as? [String: Any],
              let version = plist["CFBundleShortVersionString"] as? String,
              let buildVersion = plist["CFBundleVersion"] as? String else {
            throw XcodeToolchainError.invalidDeveloperDir(xcodeURL.path)
        }

        return XcodeInstallation(
            path: xcodeURL,
            version: version,
            buildVersion: buildVersion,
            isDeveloperDirSet: isDeveloperDirSet
        )
    }
}

private enum XcodePathResolver {
    private static let processExecutor = ProcessExecutor()

    static func findActiveXcodePath() async throws -> String? {
        let result = try await processExecutor
            .executeXcrun(arguments: ["--show-sdk-path"])

        guard result.isSuccess else {
            return nil
        }

        let output = result.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.split(separator: "/")
        if let appIndex = components
            .firstIndex(where: { $0.hasSuffix(".app") }) {
            let appPath = "/" + components[1 ... appIndex]
                .joined(separator: "/")
            return appPath
        }

        return nil
    }

    static func getCurrentDeveloperDir() async throws -> String? {
        let result = try await processExecutor.executeXcodeSelect()

        guard result.isSuccess else {
            return nil
        }

        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

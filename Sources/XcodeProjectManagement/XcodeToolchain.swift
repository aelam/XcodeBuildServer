//
//  XcodeToolchain.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

// swiftlint:disable file_length
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

public struct XcodeInstallation: Sendable {
    public let path: URL
    public let version: String
    public let buildVersion: String
    public let isDeveloperDirSet: Bool

    public var xcodebuildPath: URL {
        path.appendingPathComponent("Contents/Developer/usr/bin/xcodebuild")
    }

    public var isValid: Bool {
        FileManager.default.fileExists(atPath: xcodebuildPath.path)
    }
}

public actor XcodeToolchain {
    private var selectedInstallation: XcodeInstallation?
    private var availableInstallations: [XcodeInstallation] = []
    private let preferredVersion: String?
    private let customDeveloperDir: String?
    private let processExecutor = ProcessExecutor()

    public init(preferredVersion: String? = nil, customDeveloperDir: String? = nil) {
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
    ) async throws -> (output: String, error: String?, exitCode: Int32) {
        guard let installation = selectedInstallation else {
            throw XcodeToolchainError.xcodeNotFound
        }

        let result = try await processExecutor.executeXcodeBuild(
            arguments: arguments,
            workingDirectory: workingDirectory,
            xcodeInstallationPath: installation.path
        )

        return (output: result.output, error: result.error, exitCode: result.exitCode)
    }

    public func getXcodeVersion() async throws -> String {
        guard selectedInstallation != nil else {
            throw XcodeToolchainError.xcodeNotFound
        }

        let (output, error, exitCode) = try await executeXcodeBuild(arguments: ["-version"])
        guard exitCode == 0 else {
            let errorMessage = error ?? "xcodebuild -version failed"
            throw XcodeToolchainError.toolchainSelectionFailed(errorMessage)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if let developerDirInstallation = availableInstallations.first(where: { $0.isDeveloperDirSet }) {
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

    private func createInstallation(from xcodeURL: URL, isDeveloperDirSet: Bool) async throws -> XcodeInstallation {
        try XcodeInstallationFactory.createInstallation(from: xcodeURL, isDeveloperDirSet: isDeveloperDirSet)
    }

    private func findActiveXcodePath() async throws -> String? {
        try await XcodePathResolver.findActiveXcodePath()
    }

    private func findDeveloperDirInstallations() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []

        // Check DEVELOPER_DIR environment variable
        if let customDir = customDeveloperDir ?? ProcessInfo.processInfo.environment["DEVELOPER_DIR"] {
            let developerDirURL = URL(fileURLWithPath: customDir)
            let xcodeURL = developerDirURL.deletingLastPathComponent().deletingLastPathComponent()

            if let installation = try? await createInstallation(from: xcodeURL, isDeveloperDirSet: true) {
                installations.append(installation)
            }
        }

        // Check current xcode-select --print-path
        if let currentDeveloperDir = try? await XcodePathResolver.getCurrentDeveloperDir() {
            let developerDirURL = URL(fileURLWithPath: currentDeveloperDir)
            let xcodeURL = developerDirURL.deletingLastPathComponent().deletingLastPathComponent()

            let alreadyFound = installations.contains { $0.path.path == xcodeURL.path }
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
            if let installation = try? await createInstallation(from: xcodeURL, isDeveloperDirSet: false) {
                installations.append(installation)
            }
        }

        return installations
    }

    private func findCommonPathInstallations() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []

        let commonPaths = [
            "/Applications/Xcode.app",
            "/Applications/Xcode-beta.app"
        ]

        for path in commonPaths {
            let xcodeURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: xcodeURL.path),
               let installation = try? await createInstallation(from: xcodeURL, isDeveloperDirSet: false) {
                installations.append(installation)
            }
        }

        return installations
    }

    private func findAdditionalXcodeVersions() async -> [XcodeInstallation] {
        var installations: [XcodeInstallation] = []
        let commonPaths = ["/Applications/Xcode.app", "/Applications/Xcode-beta.app"]

        if let applicationsContents = try? FileManager.default.contentsOfDirectory(atPath: "/Applications") {
            for item in applicationsContents {
                if item.hasPrefix("Xcode"), item.hasSuffix(".app"), !commonPaths.contains("/Applications/\(item)") {
                    let xcodeURL = URL(fileURLWithPath: "/Applications/\(item)")
                    if let installation = try? await createInstallation(from: xcodeURL, isDeveloperDirSet: false) {
                        installations.append(installation)
                    }
                }
            }
        }

        return installations
    }

    private func deduplicateInstallations(_ installations: [XcodeInstallation]) -> [XcodeInstallation] {
        let uniqueInstallations = installations.reduce(into: [String: XcodeInstallation]()) { dict, installation in
            let path = installation.path.path
            if let existing = dict[path] {
                dict[path] = installation.isDeveloperDirSet ? installation : existing
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
    static func createInstallation(from xcodeURL: URL, isDeveloperDirSet: Bool) throws -> XcodeInstallation {
        let infoPlistURL = xcodeURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
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
        let result = try await processExecutor.executeXcrun(arguments: ["--show-sdk-path"])

        guard result.isSuccess else {
            return nil
        }

        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = output.split(separator: "/")
        if let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let appPath = "/" + components[1 ... appIndex].joined(separator: "/")
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

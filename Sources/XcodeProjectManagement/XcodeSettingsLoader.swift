//
//  XcodeSettingsLoader.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

public struct XcodeBuildSettings: Codable, Sendable {
    public let target: String
    public let action: String
    public let buildSettings: [String: String]

    public init(target: String, action: String, buildSettings: [String: String]) {
        self.target = target
        self.action = action
        self.buildSettings = buildSettings
    }
}

public enum XcodeLanguageDialect: String, Codable, Sendable {
    case swift = "Xcode.SourceCodeLanguage.Swift"
    case objc = "Xcode.SourceCodeLanguage.Objective-C"
    case interfaceBuilder = "Xcode.SourceCodeLanguage.InterfaceBuilder"
    case other
}

public typealias XcodeBuildSettingsForIndex = [String: [String: XcodeFileBuildSettingInfo]]

public struct XcodeFileBuildSettingInfo: Codable, Sendable {
    public var assetSymbolIndexPath: String?
    public var languageDialect: XcodeLanguageDialect
    public var outputFilePath: String?
    public var swiftASTBuiltProductsDir: String?
    public var swiftASTCommandArguments: [String]?
    public var swiftASTModuleName: String?
    public var toolchains: [String]?

    public init(
        assetSymbolIndexPath: String? = nil,
        languageDialect: XcodeLanguageDialect,
        outputFilePath: String? = nil,
        swiftASTBuiltProductsDir: String? = nil,
        swiftASTCommandArguments: [String]? = nil,
        swiftASTModuleName: String? = nil,
        toolchains: [String]? = nil
    ) {
        self.assetSymbolIndexPath = assetSymbolIndexPath
        self.languageDialect = languageDialect
        self.outputFilePath = outputFilePath
        self.swiftASTBuiltProductsDir = swiftASTBuiltProductsDir
        self.swiftASTCommandArguments = swiftASTCommandArguments
        self.swiftASTModuleName = swiftASTModuleName
        self.toolchains = toolchains
    }
}

public extension XcodeBuildSettingsForIndex {
    func fileBuildInfo(for target: String, fileName: String) -> XcodeFileBuildSettingInfo? {
        guard let targetBuildSettings = self[target] else {
            return nil
        }
        return targetBuildSettings[fileName]
    }
}

public actor XcodeSettingsLoader {
    private let commandBuilder: XcodeBuildCommandBuilder
    private let toolchain: XcodeToolchain
    private let jsonDecoder = JSONDecoder()

    public init(commandBuilder: XcodeBuildCommandBuilder, toolchain: XcodeToolchain) {
        self.commandBuilder = commandBuilder
        self.toolchain = toolchain
    }

    public func loadBuildSettings(
        target: String,
        destination: XcodeBuildDestination = .iOSSimulator
    ) async throws -> [XcodeBuildSettings] {
        let command = commandBuilder.buildSettingsCommand(
            target: target,
            destination: destination,
            forIndex: false
        )
        let output = try await runXcodeBuild(arguments: command)
        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings")
        }

        let data = Data(jsonString.utf8)
        do {
            return try jsonDecoder.decode([XcodeBuildSettings].self, from: data)
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to decode build settings: \(error)")
        }
    }

    public func loadBuildSettingsForIndex(target: String? = nil) async throws -> XcodeBuildSettingsForIndex {
        // If no target provided, get any available target
        let targetToUse: String
        if let target = target {
            targetToUse = target
        } else {
            targetToUse = try await getAnyAvailableTarget()
        }
        let command = commandBuilder.buildSettingsCommand(
            target: targetToUse,
            destination: nil, // No destination needed for index settings
            forIndex: true
        )
        let output = try await runXcodeBuild(arguments: command)
        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings for index")
        }

        let data = Data(jsonString.utf8)
        do {
            return try jsonDecoder.decode(XcodeBuildSettingsForIndex.self, from: data)
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to decode build settings for index: \(error)")
        }
    }

    public func loadIndexingPaths(
        target: String,
        buildSettings: [XcodeBuildSettings]
    ) async throws -> (indexStoreURL: URL, indexDatabaseURL: URL) {
        guard let settings = buildSettings.first(where: {
            $0.target == target && $0.action == "build"
        })?.buildSettings else {
            throw XcodeProjectError.invalidConfig("No build settings found for target: \(target)")
        }

        guard let buildFolderPath = settings["BUILD_DIR"] else {
            throw XcodeProjectError.invalidConfig("BUILD_DIR not found in build settings")
        }

        let outputFolder = URL(fileURLWithPath: buildFolderPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let indexStoreURL = outputFolder.appendingPathComponent("Index.noIndex/DataStore")
        let indexDatabaseURL = outputFolder.appendingPathComponent("IndexDatabase.noIndex")

        do {
            if !FileManager.default.fileExists(atPath: indexDatabaseURL.path) {
                try FileManager.default.createDirectory(at: indexDatabaseURL, withIntermediateDirectories: true)
            }
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to create index database directory: \(error)")
        }

        return (indexStoreURL: indexStoreURL, indexDatabaseURL: indexDatabaseURL)
    }

    public func getCompileArguments(
        fileURI: String,
        scheme: String,
        buildSettingsForIndex: XcodeBuildSettingsForIndex
    ) -> [String] {
        let filePath = URL(filePath: fileURI).path
        let fileBuildSettings = buildSettingsForIndex[scheme]?[filePath]
        return fileBuildSettings?.swiftASTCommandArguments ?? []
    }

    public func getBuildSetting(
        _ key: String,
        for target: String,
        action: String = "build",
        buildSettings: [XcodeBuildSettings]
    ) -> String? {
        buildSettings.first { $0.target == target && $0.action == action }?.buildSettings[key]
    }

    public func detectDestination(scheme: String? = nil) async throws -> XcodeBuildDestination {
        // Use showdestinations command to detect supported platforms
        // If no scheme provided, we'll need to get one from the project
        let schemeToUse: String
        if let scheme = scheme {
            schemeToUse = scheme
        } else {
            // Get any available scheme for platform detection
            schemeToUse = try await getAnyAvailableScheme()
        }

        let command = commandBuilder.showDestinationsCommand(scheme: schemeToUse)
        let output = try await runXcodeBuild(arguments: command)

        guard let destinationsOutput = output, !destinationsOutput.isEmpty else {
            // Fallback to iOS Simulator if detection fails
            return .iOSSimulator
        }

        // Parse -showdestinations output for platform indicators
        let platformMappings: [(patterns: [String], destination: XcodeBuildDestination)] = [
            (["platform:iOS", "platform=iOS Simulator"], .iOSSimulator),
            (["platform:watchOS", "platform=watchOS Simulator"], .watchOSSimulator),
            (["platform:macOS", "platform=macOS"], .macOS),
            (["platform:tvOS", "platform=tvOS Simulator"], .tvOSSimulator)
        ]

        for (patterns, destination) in platformMappings where patterns.contains(where: destinationsOutput.contains) {
            return destination
        }

        // Check for visionOS (custom handling)
        if destinationsOutput.contains("platform:visionOS") ||
           destinationsOutput.contains("platform=visionOS") {
            return .custom("generic/platform=visionOS Simulator")
        }

        // Default fallback
        return .iOSSimulator
    }

    private func getAnyAvailableTarget() async throws -> String {
        // Get targets by using build settings without specific target filter
        let command = commandBuilder.buildCommand(options: XcodeBuildOptions.buildSettingsJSON)
        let output = try await runXcodeBuild(arguments: command)

        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to list targets for target selection")
        }

        let data = Data(jsonString.utf8)
        do {
            // Parse build settings to extract target names
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            // Extract target names
            let targetNames = json.compactMap { targetSettings in
                targetSettings["TARGET_NAME"] as? String
            }

            // Prefer non-test targets
            let nonTestTargets = targetNames.filter { targetName in
                !isTestTarget(targetName)
            }

            if let nonTestTarget = nonTestTargets.first {
                return nonTestTarget
            }

            // Fallback to any target
            guard let firstTarget = targetNames.first else {
                throw XcodeProjectError.invalidConfig("No targets found in project")
            }

            return firstTarget

        } catch {
            throw XcodeProjectError.dataParsingError("Failed to parse targets: \(error)")
        }
    }

    private func isTestTarget(_ targetName: String) -> Bool {
        let testPatterns = [
            "Test", "Tests", "test", "tests",
            "UITest", "UITests", "uiTest", "uiTests",
            "UnitTest", "UnitTests", "unitTest", "unitTests"
        ]

        return testPatterns.contains { pattern in
            targetName.contains(pattern)
        }
    }

    private func getAnyAvailableScheme() async throws -> String {
        let command = commandBuilder.listSchemesCommand()
        let output = try await runXcodeBuild(arguments: command)

        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to list schemes for platform detection")
        }

        let data = Data(jsonString.utf8)
        do {
            let decoder = JSONDecoder()
            let listInfo = try decoder.decode(XcodeListInfo.self, from: data)
            guard let firstScheme = listInfo.workspace?.schemes.first else {
                throw XcodeProjectError.schemeNotFound("No schemes available for platform detection")
            }
            return firstScheme
        } catch {
            throw XcodeProjectError.dataParsingError("Failed to decode schemes for platform detection: \(error)")
        }
    }

    private func runXcodeBuild(arguments: [String]) async throws -> String? {
        let (output, _) = try await toolchain.executeXcodeBuild(arguments: arguments)
        return output
    }
}

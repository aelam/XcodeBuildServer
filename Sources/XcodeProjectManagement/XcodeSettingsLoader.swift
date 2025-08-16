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

    // Custom Codable to handle mixed buildSettings types
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.target = try container.decode(String.self, forKey: .target)
        self.action = try container.decode(String.self, forKey: .action)

        // Handle mixed value types in buildSettings
        let rawBuildSettings = try container.decode([String: BuildSettingValue].self, forKey: .buildSettings)
        self.buildSettings = rawBuildSettings.mapValues { $0.stringValue }
    }

    private enum CodingKeys: String, CodingKey {
        case target, action, buildSettings
    }
}

public enum XcodeLanguageDialect: Codable, Sendable {
    public var rawValue: String {
        switch self {
        case .c: "Xcode.SourceCodeLanguage.C"
        case .cpp: "Xcode.SourceCodeLanguage.C-Plus-Plus"
        case .swift: "Xcode.SourceCodeLanguage.Swift"
        case .objc: "Xcode.SourceCodeLanguage.Objective-C"
        case .objcCpp: "Xcode.SourceCodeLanguage.Objective-C-Plus-Plus"
        case .metal: "Xcode.SourceCodeLanguage.Metal"
        case .interfaceBuilder: "Xcode.SourceCodeLanguage.InterfaceBuilder"
        case let .other(languageName): languageName
        }
    }

    case c
    case cpp
    case swift
    case objc
    case objcCpp
    case metal
    case interfaceBuilder
    case other(languageName: String)

    public init?(rawValue: String) {
        switch rawValue {
        case "Xcode.SourceCodeLanguage.C":
            self = .c
        case "Xcode.SourceCodeLanguage.C-Plus-Plus":
            self = .cpp
        case "Xcode.SourceCodeLanguage.Swift":
            self = .swift
        case "Xcode.SourceCodeLanguage.Objective-C":
            self = .objc
        case "Xcode.SourceCodeLanguage.Objective-C-Plus-Plus":
            self = .objcCpp
        case "Xcode.SourceCodeLanguage.Metal":
            self = .metal
        case "Xcode.SourceCodeLanguage.InterfaceBuilder":
            self = .interfaceBuilder
        default:
            self = .other(languageName: rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)

        switch stringValue {
        case "Xcode.SourceCodeLanguage.C":
            self = .c
        case "Xcode.SourceCodeLanguage.C-Plus-Plus":
            self = .cpp
        case "Xcode.SourceCodeLanguage.Swift":
            self = .swift
        case "Xcode.SourceCodeLanguage.Objective-C":
            self = .objc
        case "Xcode.SourceCodeLanguage.Objective-C-Plus-Plus":
            self = .objcCpp
        case "Xcode.SourceCodeLanguage.Metal":
            self = .metal
        case "Xcode.SourceCodeLanguage.InterfaceBuilder":
            self = .interfaceBuilder
        default:
            logger.debug("Unknown language dialect: '\(stringValue)', using .other")
            self = .other(languageName: stringValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public typealias XcodeBuildSettingsForIndex = [String: [String: XcodeFileBuildSettingInfo]]

/// Represents a build setting value that can be a string or array of strings
public enum BuildSettingValue: Codable {
    case string(String)
    case array([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(
                BuildSettingValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .array(values):
            try container.encode(values)
        }
    }

    /// Convert to string representation
    public var stringValue: String {
        switch self {
        case let .string(value):
            value
        case let .array(values):
            values.joined(separator: " ")
        }
    }
}

public struct XcodeFileBuildSettingInfo: Codable, Sendable {
    public var assetSymbolIndexPath: String?
    public var languageDialect: XcodeLanguageDialect?
    public var outputFilePath: String?
    public var swiftASTBuiltProductsDir: String?
    public var swiftASTCommandArguments: [String]?
    public var swiftASTModuleName: String?
    public var toolchains: [String]?

    private enum CodingKeys: String, CodingKey {
        case assetSymbolIndexPath
        case languageDialect = "LanguageDialect" // Note: Xcode uses capital 'L'
        case outputFilePath
        case swiftASTBuiltProductsDir
        case swiftASTCommandArguments
        case swiftASTModuleName
        case toolchains
    }

    public init(
        assetSymbolIndexPath: String? = nil,
        languageDialect: XcodeLanguageDialect? = nil,
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

    // MARK: - BuildSettings

    public func loadBuildSettings(
        rootURL: URL,
        project: XcodeProjectConfiguration,
    ) async throws -> [XcodeBuildSettings] {
        let command = commandBuilder.buildCommand(
            project: project,
            options: XcodeBuildOptions.buildSettingsJSON()
        )
        let output = try await runXcodeBuild(arguments: command, workingDirectory: rootURL)
        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings")
        }

        let data = Data(jsonString.utf8)
        do {
            return try jsonDecoder.decode([XcodeBuildSettings].self, from: data)
        } catch {
            logger.debug(jsonString)
            throw XcodeProjectError.invalidConfig("Failed to decode build settings: \(error)")
        }
    }

    public func loadIndexingPaths(
        buildSettingsList: [XcodeBuildSettings]
    ) async throws -> (indexStoreURL: URL, indexDatabaseURL: URL) {
        guard let settings = buildSettingsList.first?.buildSettings else {
            throw XcodeProjectError.invalidConfig("No build settings found")
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

    // MARK: - BuildSettingsForIndex

    /// Load buildSettingsForIndex for source file discovery
    public func loadBuildSettingsForIndex(
        rootURL: URL,
        targets: [XcodeTarget],
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        try await withThrowingTaskGroup(of: XcodeBuildSettingsForIndex.self) { taskGroup in
            // group targets under same project
            let groupedTargets = Dictionary(grouping: targets) { $0.projectURL }

            for (projectURL, targets) in groupedTargets {
                taskGroup.addTask {
                    let buildSettingForProject = try await self.loadBuildSettingsForIndex(
                        rootURL: rootURL,
                        projectURL: projectURL,
                        targets: targets.map(\.name),
                        derivedDataPath: derivedDataPath
                    )
                    var targetBuildSettings: XcodeBuildSettingsForIndex = [:]
                    for (targetName, settings) in buildSettingForProject {
                        let targetIdentifier = "xcode://" + projectURL.appendingPathComponent(targetName).path
                        targetBuildSettings[targetIdentifier] = settings
                    }
                    return targetBuildSettings
                }
            }

            var buildSettings: XcodeBuildSettingsForIndex = [:]
            for try await targetSettings in taskGroup {
                buildSettings.merge(targetSettings) { _, new in new }
            }
            return buildSettings
        }
    }

    /// Load build settings for index for all targets in same project
    /// it would perform much faster than loading settings for each target individually
    private func loadBuildSettingsForIndex(
        rootURL: URL,
        projectURL: URL, // xcodeproj file URL
        targets: [String] = [],
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        let command = commandBuilder.buildCommand(
            project: .project(
                projectURL: projectURL,
                buildMode: .targets(targets),
                configuration: nil
            ),
            options: XcodeBuildOptions.buildSettingsForIndexJSON(derivedDataPath: derivedDataPath.path)
        )

        let output = try await runXcodeBuild(arguments: command, workingDirectory: rootURL)
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

    public func runXcodeBuild(
        arguments: [String],
        workingDirectory: URL
    ) async throws -> String? {
        // Set working directory to project root for better relative path resolution
        logger.debug("runXcodeBuild: arguments: \(arguments.joined(separator: " "))")
        logger.debug("runXcodeBuild: working directory: \(workingDirectory.path)")
        let result = try await toolchain.executeXcodeBuild(
            arguments: arguments,
            workingDirectory: workingDirectory
        )
        let exitCode = result.exitCode
        let output = result.output
        let error = result.error
        logger.debug("runXcodeBuild: completed exit code: \(result.exitCode)")
        logger.debug("runXcodeBuild: output length: \(output.count)")

        if !output.isEmpty {
            logger.debug("runXcodeBuild: output preview: \(String(output.prefix(200)))")
        } else {
            logger.warning("runXcodeBuild: output is empty!")
        }

        if exitCode != 0 {
            logger.error("xcodebuild command failed with exit code \(exitCode)")
            if let error {
                logger.error("Error output: \(error)")
            }
        }

        // 返回空字符串时返回nil
        return output.isEmpty ? nil : output
    }
}

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

public enum XcodeLanguageDialect: String, Codable, Sendable {
    case swift = "Xcode.SourceCodeLanguage.Swift"
    case objc = "Xcode.SourceCodeLanguage.Objective-C"
    case interfaceBuilder = "Xcode.SourceCodeLanguage.InterfaceBuilder"
    case other

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)

        switch stringValue {
        case "Xcode.SourceCodeLanguage.Swift":
            self = .swift
        case "Xcode.SourceCodeLanguage.Objective-C":
            self = .objc
        case "Xcode.SourceCodeLanguage.InterfaceBuilder":
            self = .interfaceBuilder
        default:
            logger.debug("Unknown language dialect: '\(stringValue)', using .other")
            self = .other
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

    public func loadBuildSettings(
        workspaceURL: URL? = nil,
        projectURL: URL? = nil,
        scheme: String? = nil,
        destination: XcodeBuildDestination? = .iOSSimulator
    ) async throws -> [XcodeBuildSettings] {
        let command = commandBuilder.buildSettingsCommand(
            workspaceURL: workspaceURL,
            projectURL: projectURL,
            scheme: scheme,
            target: nil, // Don't specify target for workspace
            destination: destination,
            forIndex: false
        )
        logger.debug("loadBuildSettings command: \(command.joined(separator: " "))")
        let output = try await runXcodeBuild(arguments: command)
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

    public func loadBuildSettingsForIndex(
        projectURL: URL,
        target: String? = nil,
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        let command = commandBuilder.buildSettingsCommand(
            workspaceURL: nil,
            projectURL: projectURL,
            scheme: nil,
            target: target,
            destination: nil, // No destination needed for index settings
            forIndex: true,
            derivedDataPath: derivedDataPath
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

    /// Load build settings for workspace using scheme
    public func loadBuildSettingsForWorkspace(
        workspaceURL: URL,
        scheme: String,
        destination: XcodeBuildDestination? = .iOSSimulator
    ) async throws -> [XcodeBuildSettings] {
        let command = commandBuilder.buildSettingsCommand(
            workspaceURL: workspaceURL,
            projectURL: nil,
            scheme: scheme,
            target: nil, // Don't specify target for workspace
            destination: destination,
            forIndex: false
        )
        logger.debug("loadBuildSettingsForWorkspace command: \(command.joined(separator: " "))")
        let output = try await runXcodeBuild(arguments: command)
        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings for workspace")
        }

        let data = Data(jsonString.utf8)
        do {
            return try jsonDecoder.decode([XcodeBuildSettings].self, from: data)
        } catch {
            logger.debug(jsonString)
            throw XcodeProjectError.dataParsingError("Failed to parse build settings: \(error.localizedDescription)")
        }
    }

    public func runXcodeBuildPublic(arguments: [String]) async throws -> String? {
        try await runXcodeBuild(arguments: arguments)
    }

    private func runXcodeBuild(arguments: [String]) async throws -> String? {
        // Set working directory to project root for better relative path resolution
        let workingDirectory = commandBuilder.projectIdentifier.rootURL
        logger.debug("runXcodeBuild: about to execute command with arguments: \(arguments.joined(separator: " "))")
        logger.debug("runXcodeBuild: working directory: \(workingDirectory.path)")
        let result = try await toolchain.executeXcodeBuild(
            arguments: arguments,
            workingDirectory: workingDirectory
        )
        let exitCode = result.exitCode
        let output = result.output
        let error = result.error
        logger.debug("runXcodeBuild: command completed with exit code: \(result.exitCode)")
        logger.debug("runXcodeBuild: output isEmpty: \(output.isEmpty)")
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

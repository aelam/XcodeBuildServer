//
//  XcodeSettingsManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

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

public actor XcodeSettingsManager {
    private let commandBuilder: XcodeBuildCommandBuilder
    private let toolchain: XcodeToolchain
    private let jsonDecoder = JSONDecoder()

    public private(set) var buildSettings: [XcodeBuildSettings]?
    public private(set) var buildSettingsForIndex: XcodeBuildSettingsForIndex?
    public private(set) var indexStoreURL: URL?
    public private(set) var indexDatabaseURL: URL?

    public init(commandBuilder: XcodeBuildCommandBuilder, toolchain: XcodeToolchain) {
        self.commandBuilder = commandBuilder
        self.toolchain = toolchain
    }

    public func loadBuildSettings(destination: XcodeBuildDestination = .iOSSimulator) async throws {
        let command = commandBuilder.buildSettingsCommand(destination: destination, forIndex: false)
        let output = try await runXcodeBuild(arguments: command)

        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings")
        }

        let data = Data(jsonString.utf8)
        do {
            buildSettings = try jsonDecoder.decode([XcodeBuildSettings].self, from: data)
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to decode build settings: \(error)")
        }
    }

    public func loadBuildSettingsForIndex() async throws {
        let command = commandBuilder.buildSettingsCommand(forIndex: true)
        let output = try await runXcodeBuild(arguments: command)

        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings for index")
        }

        let data = Data(jsonString.utf8)
        do {
            buildSettingsForIndex = try jsonDecoder.decode(XcodeBuildSettingsForIndex.self, from: data)
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to decode build settings for index: \(error)")
        }
    }

    public func loadIndexingPaths(scheme: String) async throws {
        guard let buildSettings = buildSettings?.first(where: {
            $0.target == scheme && $0.action == "build"
        })?.buildSettings else {
            throw XcodeProjectError.invalidConfig("No build settings found for scheme: \(scheme)")
        }

        guard let buildFolderPath = buildSettings["BUILD_DIR"] else {
            throw XcodeProjectError.invalidConfig("BUILD_DIR not found in build settings")
        }

        let outputFolder = URL(fileURLWithPath: buildFolderPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        indexStoreURL = outputFolder.appendingPathComponent("Index.noIndex/DataStore")
        let indexDatabaseURL = outputFolder.appendingPathComponent("IndexDatabase.noIndex")

        do {
            if !FileManager.default.fileExists(atPath: indexDatabaseURL.path) {
                try FileManager.default.createDirectory(at: indexDatabaseURL, withIntermediateDirectories: true)
            }
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to create index database directory: \(error)")
        }

        self.indexDatabaseURL = indexDatabaseURL
    }

    public func getCompileArguments(fileURI: String, scheme: String) -> [String] {
        let filePath = URL(filePath: fileURI).path
        guard let buildSettingsForIndex else {
            return []
        }

        let fileBuildSettings = buildSettingsForIndex[scheme]?[filePath]
        return fileBuildSettings?.swiftASTCommandArguments ?? []
    }

    public func getBuildSetting(_ key: String, for target: String, action: String = "build") -> String? {
        buildSettings?.first { $0.target == target && $0.action == action }?.buildSettings[key]
    }

    private func runXcodeBuild(arguments: [String]) async throws -> String? {
        let (output, _) = try await toolchain.executeXcodeBuild(arguments: arguments)
        return output
    }
}

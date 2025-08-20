//
//  XcodeSettingsLoader.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

public actor XcodeSettingsLoader {
    let commandBuilder: XcodeBuildCommandBuilder
    private let toolchain: XcodeToolchain
    let jsonDecoder = JSONDecoder()

    public init(commandBuilder: XcodeBuildCommandBuilder, toolchain: XcodeToolchain) {
        self.commandBuilder = commandBuilder
        self.toolchain = toolchain
    }

    public func loadPathsFromPrimayBuildSettings(
        buildSettingsList: [XcodeBuildSettings]
    ) throws -> XcodeProjectProjectBuildSettings {
        guard let settings = buildSettingsList.first?.buildSettings else {
            throw XcodeProjectError.invalidConfig("No build settings found")
        }

        guard let buildFolderPath = settings["BUILD_DIR"] else {
            throw XcodeProjectError.invalidConfig("BUILD_DIR not found in build settings")
        }

        let configuration = settings["CONFIGURATION"] ?? "Debug"

        let derivedDataPath = URL(fileURLWithPath: buildFolderPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let indexStoreURL = derivedDataPath.appendingPathComponent("Index.noIndex/DataStore")
        let indexDatabaseURL = derivedDataPath.appendingPathComponent("IndexDatabase.noIndex")
        let sdkStatCacheDir = settings["SDK_STAT_CACHE_DIR"] ?? derivedDataPath.deletingLastPathComponent().path
        let sdkStatCachePath = settings["SDK_STAT_CACHE_PATH"] ?? sdkStatCacheDir.appending("SDKStatCache")

        do {
            if !FileManager.default.fileExists(atPath: indexDatabaseURL.path) {
                try FileManager.default.createDirectory(at: indexDatabaseURL, withIntermediateDirectories: true)
            }
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to create index database directory: \(error)")
        }

        return XcodeProjectProjectBuildSettings(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL,
            configuration: configuration,
            sdkStatCacheDir: sdkStatCacheDir,
            sdkStatCachePath: sdkStatCachePath
        )
    }

    public func runXcodeBuild(
        arguments: [String],
        workingDirectory: URL
    ) async throws -> String? {
        let result = try await toolchain.executeXcodeBuild(
            arguments: arguments,
            workingDirectory: workingDirectory
        )

        // 返回空字符串时返回nil
        return result.output.isEmpty ? nil : result.output
    }
}

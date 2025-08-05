//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

enum BuildServerError: Error, CustomStringConvertible {
    case missingConfigFile
    case missingWorkspace
    case missingProject
    case buildSettingsLoadFailed
    case buildSettingsForIndexLoadFailed
    case invalidConfiguration(String)
    case xcodebuildExecutionFailed(String)
    case indexingPathsLoadFailed

    var description: String {
        switch self {
        case .missingConfigFile:
            "BSP configuration file not found"
        case .missingWorkspace:
            "No workspace specified in configuration"
        case .missingProject:
            "No project or workspace found"
        case .buildSettingsLoadFailed:
            "Failed to load Xcode build settings"
        case .buildSettingsForIndexLoadFailed:
            "Failed to load Xcode build settings for index"
        case let .invalidConfiguration(message):
            "Invalid configuration: \(message)"
        case let .xcodebuildExecutionFailed(output):
            "xcodebuild execution failed: \(output)"
        case .indexingPathsLoadFailed:
            "Failed to load indexing paths"
        }
    }
}

struct BuildServerConfig: Codable {
    static let defaultConfiguration = "Debug"

    let rootURL: URL?
    let workspace: String?
    let project: String?
    let scheme: String?
    let configuration: String?
}

actor BuildServerContext {
    private(set) var rootURL: URL?
    private(set) var config: BuildServerConfig?
    private(set) var projectManager: XcodeProjectManager?
    private(set) var projectInfo: XcodeProjectInfo?
    private(set) var settingsManager: XcodeSettingsManager?
    private(set) var indexStoreURL: URL?
    private(set) var indexDatabaseURL: URL?

    private let jsonDecoder = JSONDecoder()

    func loadProject(rootURL: URL) async throws {
        logger.debug("Loading project at \(rootURL)")
        self.rootURL = rootURL

        self.projectManager = XcodeProjectManager(rootURL: rootURL)

        guard let configFileURL = getConfigPath(for: rootURL) else {
            logger.debug("No BSP config found, using project manager auto-discovery")
            self.projectInfo = try await projectManager!.loadProject()

            // Initialize settings manager with the loaded project
            let commandBuilder = XcodeBuildCommandBuilder(projectInfo: self.projectInfo!)
            self.settingsManager = XcodeSettingsManager(commandBuilder: commandBuilder)

            try await settingsManager!.loadBuildSettings()
            try await settingsManager!.loadBuildSettingsForIndex()

            if let scheme = self.projectInfo?.scheme {
                try await settingsManager!.loadIndexingPaths(scheme: scheme)
                self.indexStoreURL = await settingsManager?.indexStoreURL
                self.indexDatabaseURL = await settingsManager?.indexDatabaseURL
            }
            logger.debug("Project loaded via auto-discovery: \(String(describing: self.projectInfo))")
            return
        }

        self.config = try loadConfig(configFileURL: configFileURL)
        logger.debug("Config loaded: \(String(describing: self.config))")

        guard let config else {
            throw BuildServerError.missingConfigFile
        }

        logger.debug("Loading Xcode project with config")
        self.projectInfo = try await projectManager!.loadProject(
            scheme: config.scheme,
            configuration: config.configuration ?? "Debug"
        )
        logger.debug("Xcode project loaded: \(String(describing: self.projectInfo))")

        // Initialize settings manager with the loaded project
        let commandBuilder = XcodeBuildCommandBuilder(projectInfo: self.projectInfo!)
        self.settingsManager = XcodeSettingsManager(commandBuilder: commandBuilder)

        try await settingsManager!.loadBuildSettings()
        try await settingsManager!.loadBuildSettingsForIndex()

        if let scheme = self.projectInfo?.scheme {
            try await settingsManager!.loadIndexingPaths(scheme: scheme)
            self.indexStoreURL = await settingsManager?.indexStoreURL
            self.indexDatabaseURL = await settingsManager?.indexDatabaseURL
        }
        logger.debug("Settings manager initialized and build settings loaded")
    }

    private func getXcodeBuildBasicArguments() throws -> [String] {
        guard let projectInfo else {
            throw BuildServerError.invalidConfiguration("Xcode project not loaded")
        }

        var arguments: [String] = []

        switch projectInfo.projectType {
        case let .explicitWorkspace(url):
            arguments.append(contentsOf: ["-workspace", url.path])
        case let .implicitProjectWorkspace(url):
            let projectURL = url.deletingLastPathComponent()
            arguments.append(contentsOf: ["-project", projectURL.path])
        }

        if let scheme = projectInfo.scheme {
            arguments.append(contentsOf: ["-scheme", scheme])
        }

        arguments.append(contentsOf: ["-configuration", projectInfo.configuration])

        return arguments
    }

    // MARK: - Private

    private func getConfigPath(for workspaceFolder: URL? = nil) -> URL? {
        guard let workspaceFolder else {
            return nil
        }

        let configSearchPaths = [
            // Standard BSP config location
            workspaceFolder.appendingPathComponent(".bsp"),
            // Legacy location for compatibility
            workspaceFolder.appendingPathComponent("buildServer.json", isDirectory: false)
        ]

        // First try standard BSP .bsp directory
        if let bspDir = configSearchPaths.first,
           FileManager.default.fileExists(atPath: bspDir.path) {
            do {
                let jsonFiles = try FileManager.default
                    .contentsOfDirectory(at: bspDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                if let firstConfig = jsonFiles.first {
                    logger.debug("Found BSP config at: \(firstConfig.path)")
                    return firstConfig
                }
            } catch {
                logger.debug("Failed to read .bsp directory: \(error)")
            }
        }

        // Fallback to legacy location
        if let legacyConfig = configSearchPaths.last,
           FileManager.default.fileExists(atPath: legacyConfig.path) {
            logger.debug("Found legacy config at: \(legacyConfig.path)")
            return legacyConfig
        }

        logger.debug("No BSP configuration file found in workspace")
        return nil
    }

    private func loadConfig(configFileURL: URL) throws -> BuildServerConfig? {
        logger.debug("Loading config from: \(configFileURL.path)")

        do {
            let data = try Data(contentsOf: configFileURL)
            var config = try JSONDecoder().decode(BuildServerConfig.self, from: data)

            // Validate and provide defaults
            config = validateAndNormalizeConfig(config, rootURL: rootURL)

            logger.debug("Config loaded successfully: \(String(describing: config))")
            return config
        } catch {
            logger.error("Failed to load config from \(configFileURL.path): \(error)")
            throw BuildServerError.invalidConfiguration("Failed to parse config file: \(error.localizedDescription)")
        }
    }
}

extension BuildServerContext {
    func getCompileArguments(fileURI: String) async -> [String] {
        guard
            let settingsManager,
            let scheme = projectInfo?.scheme
        else {
            return []
        }

        return await settingsManager.getCompileArguments(fileURI: fileURI, scheme: scheme)
    }

    func getBuildSetting(_ key: String, for target: String, action: String = "build") async -> String? {
        await settingsManager?.getBuildSetting(key, for: target, action: action)
    }
}

// MARK: - Private Configuration Helpers

private extension BuildServerContext {
    func validateAndNormalizeConfig(_ config: BuildServerConfig, rootURL: URL?) -> BuildServerConfig {
        var normalizedConfig = config

        // Provide default configuration if none specified
        if normalizedConfig.configuration == nil {
            normalizedConfig = BuildServerConfig(
                rootURL: normalizedConfig.rootURL,
                workspace: normalizedConfig.workspace,
                project: normalizedConfig.project,
                scheme: normalizedConfig.scheme,
                configuration: BuildServerConfig.defaultConfiguration
            )
            logger.debug("Using default configuration: \(BuildServerConfig.defaultConfiguration)")
        }

        return normalizedConfig
    }
}

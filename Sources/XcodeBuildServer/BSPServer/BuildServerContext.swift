//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

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
    private(set) var config: BuildServerConfig? // Optional because not used in auto-discovery mode
    private(set) var projectManager: XcodeProjectManager?
    private(set) var projectInfo: XcodeProjectInfo?
    private(set) var settingsManager: XcodeSettingsManager?
    private(set) var indexStoreURL: URL?
    private(set) var indexDatabaseURL: URL?

    private let jsonDecoder = JSONDecoder()

    // Computed property to check if the context is properly loaded
    var isLoaded: Bool {
        projectManager != nil && projectInfo != nil && settingsManager != nil
    }

    // Safe accessors for core components (throws if not loaded)
    private var loadedProjectManager: XcodeProjectManager {
        get throws {
            guard let projectManager else {
                throw BuildServerError.invalidConfiguration("BuildServerContext not loaded - call loadProject() first")
            }
            return projectManager
        }
    }

    private var loadedProjectInfo: XcodeProjectInfo {
        get throws {
            guard let projectInfo else {
                throw BuildServerError.invalidConfiguration("BuildServerContext not loaded - call loadProject() first")
            }
            return projectInfo
        }
    }

    private var loadedSettingsManager: XcodeSettingsManager {
        get throws {
            guard let settingsManager else {
                throw BuildServerError.invalidConfiguration("BuildServerContext not loaded - call loadProject() first")
            }
            return settingsManager
        }
    }

    func loadProject(rootURL: URL) async throws {
        logger.debug("Loading project at \(rootURL)")
        self.rootURL = rootURL

        self.projectManager = XcodeProjectManager(rootURL: rootURL)

        guard let configFileURL = getConfigPath(for: rootURL) else {
            logger.debug("No BSP config found, using project manager auto-discovery")
            self.projectInfo = try await loadedProjectManager.loadProject()

            // Initialize settings manager with the loaded project
            let commandBuilder = try XcodeBuildCommandBuilder(projectInfo: loadedProjectInfo)
            self.settingsManager = XcodeSettingsManager(commandBuilder: commandBuilder)

            try await loadedSettingsManager.loadBuildSettings()
            try await loadedSettingsManager.loadBuildSettingsForIndex()

            if let scheme = try loadedProjectInfo.scheme {
                try await loadedSettingsManager.loadIndexingPaths(scheme: scheme)
                self.indexStoreURL = try await (loadedSettingsManager).indexStoreURL
                self.indexDatabaseURL = try await (loadedSettingsManager).indexDatabaseURL
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
        self.projectInfo = try await loadedProjectManager.loadProject(
            scheme: config.scheme,
            configuration: config.configuration ?? "Debug"
        )
        logger.debug("Xcode project loaded: \(String(describing: self.projectInfo))")

        // Initialize settings manager with the loaded project
        let commandBuilder = try XcodeBuildCommandBuilder(projectInfo: loadedProjectInfo)
        self.settingsManager = XcodeSettingsManager(commandBuilder: commandBuilder)

        try await loadedSettingsManager.loadBuildSettings()
        try await loadedSettingsManager.loadBuildSettingsForIndex()

        if let scheme = try loadedProjectInfo.scheme {
            try await loadedSettingsManager.loadIndexingPaths(scheme: scheme)
            self.indexStoreURL = try await (loadedSettingsManager).indexStoreURL
            self.indexDatabaseURL = try await (loadedSettingsManager).indexDatabaseURL
        }
        logger.debug("Settings manager initialized and build settings loaded")
    }

    private func getXcodeBuildBasicArguments() throws -> [String] {
        let projectInfo = try loadedProjectInfo
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
        do {
            let settingsManager = try loadedSettingsManager
            let projectInfo = try loadedProjectInfo

            guard let scheme = projectInfo.scheme else {
                return []
            }

            return await settingsManager.getCompileArguments(fileURI: fileURI, scheme: scheme)
        } catch {
            logger.error("Failed to get compile arguments: \(error)")
            return []
        }
    }

    func getBuildSetting(_ key: String, for target: String, action: String = "build") async -> String? {
        do {
            let settingsManager = try loadedSettingsManager
            return await settingsManager.getBuildSetting(key, for: target, action: action)
        } catch {
            logger.error("Failed to get build setting: \(error)")
            return nil
        }
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

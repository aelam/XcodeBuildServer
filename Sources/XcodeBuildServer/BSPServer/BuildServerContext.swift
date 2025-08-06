//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

public actor BuildServerContext {
    private(set) var rootURL: URL?
    /// loaded from `.bsp/xcode.json` or legacy `buildServer.json`
    /// This configuration is used to initialize the project manager and settings manager.
    /// If no config is found, the project manager will auto-discover the project.
    /// If a config is found, it will be used to load the project.
    /// If the working directory has more than one xcworkspace or project,
    /// It's better to specify the workspace or project in the config.
    private(set) var config: XcodeBSPConfiguration?
    private(set) var toolchain: XcodeToolchain? // Shared toolchain for all components
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

    private var loadedToolchain: XcodeToolchain {
        get throws {
            guard let toolchain else {
                throw BuildServerError.invalidConfiguration("BuildServerContext not loaded - call loadProject() first")
            }
            return toolchain
        }
    }

    func loadProject(rootURL: URL) async throws {
        logger.debug("Loading project at \(rootURL)")
        self.rootURL = rootURL

        // Initialize shared toolchain first
        self.toolchain = XcodeToolchain()
        try await loadedToolchain.initialize()

        self.projectManager = try XcodeProjectManager(rootURL: rootURL, toolchain: loadedToolchain)

        guard let configFileURL = getConfigPath(for: rootURL) else {
            logger.debug("No BSP config found, using project manager auto-discovery")
            self.projectInfo = try await loadedProjectManager.loadProject()

            // Initialize settings manager with the loaded project
            let commandBuilder = try XcodeBuildCommandBuilder(projectInfo: loadedProjectInfo)
            self.settingsManager = try XcodeSettingsManager(commandBuilder: commandBuilder, toolchain: loadedToolchain)

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
        self.projectInfo = try await loadedProjectManager.loadProject(from: config.projectReference)
        logger.debug("Xcode project loaded: \(String(describing: self.projectInfo))")

        // Initialize settings manager with the loaded project
        let commandBuilder = try XcodeBuildCommandBuilder(projectInfo: loadedProjectInfo)
        self.settingsManager = try XcodeSettingsManager(commandBuilder: commandBuilder, toolchain: loadedToolchain)

        try await loadedSettingsManager.loadBuildSettings()
        try await loadedSettingsManager.loadBuildSettingsForIndex()

        if let scheme = try loadedProjectInfo.scheme {
            try await loadedSettingsManager.loadIndexingPaths(scheme: scheme)
            self.indexStoreURL = try await (loadedSettingsManager).indexStoreURL
            self.indexDatabaseURL = try await (loadedSettingsManager).indexDatabaseURL
        }
        logger.debug("Settings manager initialized and build settings loaded")
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

    private func loadConfig(configFileURL: URL) throws -> XcodeBSPConfiguration? {
        logger.debug("Loading config from: \(configFileURL.path)")

        do {
            let data = try Data(contentsOf: configFileURL)
            var config = try JSONDecoder().decode(XcodeBSPConfiguration.self, from: data)

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

    // MARK: - BuildTarget Factory Methods

    public func createBuildTargets() async throws -> [BuildTarget] {
        let projectManager = try loadedProjectManager
        let projectInfo = try loadedProjectInfo

        let targetInfos = try await projectManager.extractTargetInfo()
        var buildTargets: [BuildTarget] = []

        for targetInfo in targetInfos {
            let buildTarget = await createBuildTarget(from: targetInfo, projectInfo: projectInfo)
            buildTargets.append(buildTarget)
        }

        return buildTargets
    }

    private func createBuildTarget(
        from targetInfo: XcodeTargetInfo,
        projectInfo: XcodeProjectInfo
    ) async -> BuildTarget {
        let targetID = createBuildTargetIdentifier(targetName: targetInfo.name, projectInfo: projectInfo)
        let baseDirectory = try? URI(string: projectInfo.rootURL.absoluteString)
        let tags = classifyTarget(targetInfo)
        let languages = mapLanguages(from: targetInfo.supportedLanguages)
        let capabilities = createCapabilities(for: targetInfo)
        let sourceKitData = await createSourceKitData()

        return BuildTarget(
            id: targetID,
            displayName: targetInfo.name,
            baseDirectory: baseDirectory,
            tags: tags,
            languageIds: languages,
            dependencies: [], // TODO: Extract dependencies from build settings
            capabilities: capabilities,
            dataKind: .sourceKit,
            data: sourceKitData?.encodeToLSPAny()
        )
    }

    private func createBuildTargetIdentifier(
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) -> BuildTargetIdentifier {
        let uriString: String
        switch projectInfo.projectType {
        case .explicitWorkspace:
            uriString = "xcode:///\(projectInfo.workspaceName)/\(targetName)"
        case .implicitProjectWorkspace:
            let projectName = projectInfo.projectName ?? "Unknown"
            uriString = "xcode:///\(projectName)/\(targetName)"
        }

        if let uri = try? URI(string: uriString) {
            return BuildTargetIdentifier(uri: uri)
        } else {
            // swiftlint:disable:next force_try
            let fallbackURI = try! URI(string: "xcode:///unknown/\(targetName)")
            return BuildTargetIdentifier(uri: fallbackURI)
        }
    }

    private func classifyTarget(_ targetInfo: XcodeTargetInfo) -> [BuildTargetTag] {
        var tags: [BuildTargetTag] = []

        if targetInfo.isUITestTarget {
            tags.append(.integrationTest)
        } else if targetInfo.isTestTarget {
            tags.append(.test)
        } else if targetInfo.isApplicationTarget {
            tags.append(.application)
        } else if targetInfo.isLibraryTarget {
            tags.append(.library)
        } else {
            // Default to library for unknown types
            tags.append(.library)
        }

        return tags
    }

    private func mapLanguages(from languageStrings: Set<String>) -> [Language] {
        languageStrings.compactMap { languageString in
            switch languageString {
            case "swift":
                .swift
            case "objective-c":
                .objective_c
            case "c":
                .c
            case "cpp":
                .cpp
            default:
                nil
            }
        }
    }

    private func createCapabilities(for targetInfo: XcodeTargetInfo) -> BuildTargetCapabilities {
        BuildTargetCapabilities(
            canCompile: true, // All Xcode targets can compile
            canTest: targetInfo.isTestTarget,
            canRun: targetInfo.isRunnableTarget,
            canDebug: true // Xcode supports debugging for all targets
        )
    }

    private func createSourceKitData() async -> SourceKitBuildTarget? {
        guard let toolchain,
              let installation = await toolchain.getSelectedInstallation() else {
            return nil
        }

        let toolchainURI = try? URI(string: installation.path.absoluteString)
        return SourceKitBuildTarget(toolchain: toolchainURI)
    }
}

private extension BuildServerContext {
    func validateAndNormalizeConfig(_ config: XcodeBSPConfiguration, rootURL: URL?) -> XcodeBSPConfiguration {
        var normalizedConfig = config

        // Provide default configuration if none specified
        if normalizedConfig.configuration == nil {
            normalizedConfig = XcodeBSPConfiguration(
                workspace: normalizedConfig.workspace,
                project: normalizedConfig.project,
                scheme: normalizedConfig.scheme,
                configuration: XcodeBSPConfiguration.defaultConfiguration
            )
            logger.debug("Using default configuration: \(XcodeBSPConfiguration.defaultConfiguration)")
        }

        return normalizedConfig
    }
}

//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

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
            return "BSP configuration file not found"
        case .missingWorkspace:
            return "No workspace specified in configuration"
        case .missingProject:
            return "No project or workspace found"
        case .buildSettingsLoadFailed:
            return "Failed to load Xcode build settings"
        case .buildSettingsForIndexLoadFailed:
            return "Failed to load Xcode build settings for index"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .xcodebuildExecutionFailed(let output):
            return "xcodebuild execution failed: \(output)"
        case .indexingPathsLoadFailed:
            return "Failed to load indexing paths"
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

struct XcodeProject {
    let workspace: String?
    let project: String?
    let scheme: String?
    var configuration: String?
}

actor BuildServerContext {
    private(set) var rootURL: URL?
    private(set) var config: BuildServerConfig?
    private(set) var xcodeProject: XcodeProject?
    private(set) var buildSettings: [BuildSettings]?
    private(set) var buildSettingsForIndex: BuildSettingsForIndex?
    private(set) var indexStoreURL: URL?
    private(set) var indexDatabaseURL: URL?

    private let jsonDecoder = JSONDecoder()

    func loadProject(rootURL: URL) async throws {
        logger.debug("Loading project at \(rootURL)")
        self.rootURL = rootURL
        guard let configFileURL = getConfigPath(for: rootURL) else {
            throw BuildServerError.missingConfigFile
        }
        self.config = try loadConfig(configFileURL: configFileURL)
        logger.debug("Config loaded: \(String(describing: self.config))")

        guard let config else {
            throw BuildServerError.missingConfigFile
        }

        logger.debug("Loading Xcode project")
        xcodeProject = XcodeProject(
            workspace: config.workspace,
            project: config.project,
            scheme: config.scheme,
            configuration: config.configuration
        )
        logger.debug("Xcode project loaded: \(String(describing: self.xcodeProject))")
        try await loadXcodeBuildSettings()
        try await loadXcodeBuildSettingsForIndex()
        try await loadIndexingPaths()
        logger.debug("Build settings loaded: \(String(describing: self.buildSettings))")
    }

    private func loadXcodeBuildSettings() async throws {
        // xcodebuild -showBuildSettings -json
        // Load the index store
        var arguments = try getXcodeBuildBasicArguments()
        arguments.append(contentsOf: ["-destination", "generic/platform=iOS Simulator"])
        arguments.append(contentsOf: ["-showBuildSettings", "-json"])
        guard let json = try await xcodebuild(arguments: arguments), !json.isEmpty else {
            throw BuildServerError.buildSettingsLoadFailed
        }
        let data = Data(json.utf8)
        logger.debug("Build settings JSON: \(String(data: data, encoding: .utf8) ?? "nil", privacy: .public)")
        do {
            buildSettings = try jsonDecoder.decode([BuildSettings].self, from: data)
            logger.debug("Build settings: \(String(describing: self.buildSettings), privacy: .public)")
        } catch {
            logger.error("Failed to decode build settings: \(error)")
            throw BuildServerError.buildSettingsLoadFailed
        }
    }

    private func loadXcodeBuildSettingsForIndex() async throws {
        // xcodebuild -showBuildSettingsForIndex -json
        var arguments = try getXcodeBuildBasicArguments()
        // arguments.append(contentsOf: ["-destination", "generic/platform=iOS Simulator"])
        arguments.append(contentsOf: ["-showBuildSettingsForIndex", "-json"])
        guard let json = try await xcodebuild(arguments: arguments), !json.isEmpty else {
            throw BuildServerError.buildSettingsForIndexLoadFailed
        }
        logger.debug("Build settings for index JSON: \(json, privacy: .public)")
        let data = Data(json.utf8)
        do {
            buildSettingsForIndex = try jsonDecoder.decode(BuildSettingsForIndex.self, from: data)
            logger.debug("Build settings for index: \(String(describing: self.buildSettingsForIndex), privacy: .public)")
        } catch {
            logger.error("Failed to decode build settings for index: \(error)")
            throw BuildServerError.buildSettingsForIndexLoadFailed
        }
    }

    private func loadIndexingPaths() async throws {
        guard let scheme = xcodeProject?.scheme else {
            throw BuildServerError.invalidConfiguration("No scheme available for indexing paths")
        }
        
        guard let buildSettings = buildSettings?.first(where: { $0.target == scheme && $0.action == "build" })?.buildSettings else {
            throw BuildServerError.invalidConfiguration("No build settings found for scheme: \(scheme)")
        }
        
        guard let buildFolderPath = buildSettings["BUILD_DIR"] else {
            throw BuildServerError.invalidConfiguration("BUILD_DIR not found in build settings")
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
            logger.error("Failed to create index database directory: \(error)")
            throw BuildServerError.indexingPathsLoadFailed
        }

        self.indexDatabaseURL = indexDatabaseURL
        logger.debug("Index store: \(String(describing: self.indexStoreURL), privacy: .public)")
    }

    private func getXcodeBuildBasicArguments() throws -> [String] {
        guard let xcodeProject else {
            throw BuildServerError.invalidConfiguration("Xcode project not loaded")
        }

        var arguments: [String] = []
        if let workspace = xcodeProject.workspace {
            arguments.append(contentsOf: ["-workspace", workspace])
        } else if let project = xcodeProject.project {
            arguments.append(contentsOf: ["-project", project])
        } else {
            throw BuildServerError.missingProject
        }

        if let scheme = xcodeProject.scheme {
            arguments.append(contentsOf: ["-scheme", scheme])
        }

        if let configuration = xcodeProject.configuration {
            arguments.append(contentsOf: ["-configuration", configuration])
        }
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
    
    private func validateAndNormalizeConfig(_ config: BuildServerConfig, rootURL: URL?) -> BuildServerConfig {
        var normalizedConfig = config
        
        // Ensure we have either workspace or project
        if normalizedConfig.workspace == nil && normalizedConfig.project == nil {
            logger.debug("No workspace or project specified, attempting to find one")
            normalizedConfig = findWorkspaceOrProject(in: normalizedConfig, rootURL: rootURL)
        }
        
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
    
    private func findWorkspaceOrProject(in config: BuildServerConfig, rootURL: URL?) -> BuildServerConfig {
        guard let rootURL = rootURL else { return config }
        
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
            
            // Look for .xcworkspace first
            if let workspace = contents.first(where: { $0.pathExtension == "xcworkspace" }) {
                let workspaceName = workspace.lastPathComponent
                logger.debug("Found workspace: \(workspaceName)")
                return BuildServerConfig(
                    rootURL: config.rootURL,
                    workspace: workspaceName,
                    project: config.project,
                    scheme: config.scheme,
                    configuration: config.configuration
                )
            }
            
            // Fallback to .xcodeproj
            if let project = contents.first(where: { $0.pathExtension == "xcodeproj" }) {
                let projectName = project.lastPathComponent
                logger.debug("Found project: \(projectName)")
                return BuildServerConfig(
                    rootURL: config.rootURL,
                    workspace: config.workspace,
                    project: projectName,
                    scheme: config.scheme,
                    configuration: config.configuration
                )
            }
        } catch {
            logger.debug("Failed to scan directory for Xcode projects: \(error)")
        }
        
        return config
    }
}

extension BuildServerContext {
    func getCompileArguments(fileURI: String) -> [String] {
        let filePath = URL(filePath: fileURI).path
        guard
            let buildSettingsForIndex,
            let scheme = xcodeProject?.scheme
        else {
            return []
        }

        let fileBuildSettings = buildSettingsForIndex[scheme]?[filePath]
        return fileBuildSettings?.swiftASTCommandArguments ?? []
    }
}

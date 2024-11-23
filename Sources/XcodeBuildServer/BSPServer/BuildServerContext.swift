//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

enum BuildServerError: Error {
    case missingConfigFile
    case missingWorkspace
    case buildSettingsLoadFailed
    case buildSettingsForIndexLoadFailed
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

final class BuildServerContext: Sendable {
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
        var arguments = getXcodeBuildBasicArguments()
        arguments.append(contentsOf: ["-destination", "generic/platform=iOS Simulator"])
        arguments.append(contentsOf: ["-showBuildSettings", "-json"])
        guard let json = try await xcodebuild(arguments: arguments), !json.isEmpty else {
            throw BuildServerError.buildSettingsLoadFailed
        }
        let data = Data(json.utf8)
        logger.debug("Build settings JSON: \(String(data: data, encoding: .utf8) ?? "nil", privacy: .public)")
        buildSettings = try jsonDecoder.decode([BuildSettings].self, from: data)
        logger.debug("Build settings: \(String(describing: self.buildSettings), privacy: .public)")
    }

    private func loadXcodeBuildSettingsForIndex() async throws {
        // xcodebuild -showBuildSettingsForIndex -json
        var arguments = getXcodeBuildBasicArguments()
        // arguments.append(contentsOf: ["-destination", "generic/platform=iOS Simulator"])
        arguments.append(contentsOf: ["-showBuildSettingsForIndex", "-json"])
        guard let json = try await xcodebuild(arguments: arguments), !json.isEmpty else {
            throw BuildServerError.buildSettingsLoadFailed
        }
        logger.debug("Build settings for index JSON: \(json, privacy: .public)")
        let data = Data(json.utf8)
        buildSettingsForIndex = try jsonDecoder.decode(BuildSettingsForIndex.self, from: data)
        logger.debug("Build settings for index: \(String(describing: self.buildSettingsForIndex), privacy: .public)")
    }

    private func loadIndexingPaths() async throws {
        guard
            let scheme = xcodeProject?.scheme,
            let buildSettings = buildSettings?.first(where: { $0.target == scheme && $0.action == "build" })?.buildSettings,
            let buildFolderPath = buildSettings["BUILD_DIR"]
        else {
            throw BuildServerError.buildSettingsLoadFailed
        }

        let outputFolder = URL(fileURLWithPath: buildFolderPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        indexStoreURL = outputFolder.appendingPathComponent("Index.noIndex/DataStore")
        let indexDatabaseURL = outputFolder.appendingPathComponent("IndexDatabase.noIndex")

        if !FileManager.default.fileExists(atPath: indexDatabaseURL.path) {
            try FileManager.default.createDirectory(at: indexDatabaseURL, withIntermediateDirectories: true)
        }

        self.indexDatabaseURL = indexDatabaseURL
        logger.debug("Index store: \(String(describing: self.indexStoreURL), privacy: .public)")
    }

    private func getXcodeBuildBasicArguments() -> [String] {
        guard let xcodeProject else {
            fatalError("Xcode project not loaded")
        }

        var arguments: [String] = []
        if let workspace = xcodeProject.workspace {
            arguments.append(contentsOf: ["-workspace", workspace])
        } else if let project = xcodeProject.project {
            arguments.append(contentsOf: ["-project", project])
        } else {
            fatalError("No workspace or project found")
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

        let buildServerConfigLocation: URL = workspaceFolder.appending(component: ".bsp")

        let jsonFiles =
            try? FileManager.default.contentsOfDirectory(at: buildServerConfigLocation, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

        if let configFileURL = jsonFiles?.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first,
           FileManager.default.fileExists(atPath: configFileURL.path)
        {
            return configFileURL
        }

        // Pre Swift 6.1 SourceKit-LSP looked for `buildServer.json` in the project root. Maintain this search location for
        // compatibility even though it's not a standard BSP search location.
        let rootBuildServerJSONFile = workspaceFolder.appending(component: "buildServer.json")
        if FileManager.default.fileExists(atPath: rootBuildServerJSONFile.path) {
            return rootBuildServerJSONFile
        }

        return nil
    }

    private func loadConfig(configFileURL: URL) throws -> BuildServerConfig? {
        let data = try Data(contentsOf: configFileURL)
        let config = try JSONDecoder().decode(BuildServerConfig.self, from: data)
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

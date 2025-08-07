//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public struct XcodeListInfo: Codable, Sendable {
    public let workspace: XcodeListWorkspace?

    public struct XcodeListWorkspace: Codable, Sendable {
        public let name: String
        public let schemes: [String]
    }
}

public struct XcodeTargetInfo: Sendable {
    public let name: String
    public let productType: String?
    public let buildSettings: [String: String]

    public var xcodeProductType: XcodeProductType? {
        guard let productType else { return nil }
        return XcodeProductType(rawValue: productType)
    }

    public var isTestTarget: Bool {
        xcodeProductType?.isTestType == true || name.contains("Test")
    }

    public var isUITestTarget: Bool {
        xcodeProductType == .uiTest || name.contains("UITest")
    }

    public var isRunnableTarget: Bool {
        xcodeProductType?.isRunnableType == true
    }

    public var isApplicationTarget: Bool {
        xcodeProductType?.isApplicationType == true
    }

    public var isLibraryTarget: Bool {
        xcodeProductType?.isLibraryType == true
    }

    public var supportedLanguages: Set<String> {
        var languages: Set<String> = []

        if buildSettings["SWIFT_VERSION"] != nil {
            languages.insert("swift")
        }
        if buildSettings["CLANG_ENABLE_OBJC_ARC"] == "YES" {
            languages.insert("objective-c")
        }
        if buildSettings["GCC_VERSION"] != nil {
            languages.insert("c")
        }
        if buildSettings["CLANG_CXX_LANGUAGE_STANDARD"] != nil {
            languages.insert("cpp")
        }

        // Default for Xcode projects
        if languages.isEmpty {
            languages = ["swift", "objective-c"]
        }

        return languages
    }

    public init(name: String, productType: String?, buildSettings: [String: String]) {
        self.name = name
        self.productType = productType
        self.buildSettings = buildSettings
    }
}

public struct XcodeProjectIdentifier: Sendable {
    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
}

public struct XcodeProjectBasicInfo: Sendable {
    public struct XcodeSchemeInfo: Sendable {
        public let name: String
        public let configuration: String?
    }

    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
    public let schemeInfoList: [XcodeSchemeInfo]
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL

    public init(
        rootURL: URL,
        projectLocation: XcodeProjectLocation,
        schemeInfoList: [XcodeSchemeInfo] = [],
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL
    ) {
        self.rootURL = rootURL
        self.projectLocation = projectLocation
        self.schemeInfoList = schemeInfoList
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
    }

    public var workspaceURL: URL {
        switch projectLocation {
        case let .explicitWorkspace(url), let .implicitWorkspace(_, url):
            url
        }
    }

    public var name: String {
        switch projectLocation {
        case let .explicitWorkspace(url), let .implicitWorkspace(url, _):
            url.lastPathComponent
        }
    }
}

public actor XcodeProjectManager {
    public let rootURL: URL
    private let locator: XcodeProjectLocator
    private(set) var currentProject: XcodeProjectBasicInfo?
    private let toolchain: XcodeToolchain
    private let projectReference: XcodeProjectReference?

    public init(
        rootURL: URL,
        projectReference: XcodeProjectReference? = nil,
        toolchain: XcodeToolchain,
        locator: XcodeProjectLocator
    ) {
        self.rootURL = rootURL
        self.projectReference = projectReference
        self.toolchain = toolchain
        self.locator = locator
    }

    public func loadProjectBasicInfo() async throws -> XcodeProjectBasicInfo {
        // Initialize toolchain first
        try await toolchain.initialize()

        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: projectReference
        )
        let projectInfo = try await resolveProjectBasic(for: projectLocation)
        currentProject = projectInfo
        return projectInfo
    }

    private func resolveProjectBasic(
        for projectLocation: XcodeProjectLocation
    ) async throws -> XcodeProjectBasicInfo {
        let projectIdentifier = XcodeProjectIdentifier(rootURL: rootURL, projectLocation: projectLocation)
        let commandBuilder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)

        // Get all available schemes from xcodebuild -list
        let allSchemes = try await loadAllSchemes(commandBuilder: commandBuilder)

        // Determine which schemes to load based on projectReference
        let schemesToLoad = try determineSchemesToLoad(allSchemes: allSchemes)

        // Load scheme information for selected schemes
        let schemeInfoList = try await loadSchemeInfoList(
            schemes: schemesToLoad,
            commandBuilder: commandBuilder
        )

        // Get index URLs from the first available scheme (shared per workspace)
        let indexPaths = try await loadIndexURLs(
            scheme: schemesToLoad.first ?? allSchemes.first,
            commandBuilder: commandBuilder
        )

        return XcodeProjectBasicInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            schemeInfoList: schemeInfoList,
            derivedDataPath: indexPaths.derivedDataPath,
            indexStoreURL: indexPaths.indexStoreURL,
            indexDatabaseURL: indexPaths.indexDatabaseURL
        )
    }

    private func loadAllSchemes(commandBuilder: XcodeBuildCommandBuilder) async throws -> [String] {
        let arguments = commandBuilder.buildCommand(options: XcodeBuildOptions.listSchemesJSON)
        let (output, _) = try await toolchain.executeXcodeBuild(
            arguments: arguments,
            workingDirectory: rootURL
        )

        guard let data = output.data(using: .utf8) else {
            throw XcodeProjectError.buildSettingsNotFound
        }

        do {
            let listInfo = try JSONDecoder().decode(XcodeListInfo.self, from: data)
            return listInfo.workspace?.schemes ?? []
        } catch {
            throw XcodeProjectError.dataParsingError("Failed to parse schemes: \(error.localizedDescription)")
        }
    }

    private func determineSchemesToLoad(allSchemes: [String]) throws -> [String] {
        if let specifiedScheme = projectReference?.scheme {
            // If xcodeProjectReference provides a specific scheme, only load that one
            guard allSchemes.contains(specifiedScheme) else {
                throw XcodeProjectError.schemeNotFound(specifiedScheme)
            }
            return [specifiedScheme]
        } else {
            // Otherwise, load all schemes to provide as BSP targets
            return allSchemes
        }
    }

    private func loadSchemeInfoList(
        schemes: [String],
        commandBuilder: XcodeBuildCommandBuilder
    ) async throws -> [XcodeProjectBasicInfo.XcodeSchemeInfo] {
        schemes.map { scheme in
            XcodeProjectBasicInfo.XcodeSchemeInfo(
                name: scheme,
                configuration: projectReference?.configuration
            )
        }
    }

    private func loadIndexURLs(
        scheme: String?,
        commandBuilder: XcodeBuildCommandBuilder
    ) async throws -> XcodeIndexPaths {
        guard let scheme else {
            throw XcodeProjectError.indexPathsError("No schemes available to determine index URLs")
        }

        // Get build settings to determine derived data path and index URLs
        let buildCommand = commandBuilder.buildCommand(
            scheme: scheme,
            configuration: projectReference?.configuration ?? "Debug",
            options: XcodeBuildOptions.buildSettingsForIndexJSON
        )

        let (output, _) = try await toolchain.executeXcodeBuild(
            arguments: buildCommand,
            workingDirectory: rootURL
        )

        guard let data = output.data(using: .utf8) else {
            throw XcodeProjectError.buildSettingsNotFound
        }

        do {
            return try XcodeIndexPathResolver.resolveIndexPaths(from: data)
        } catch {
            throw XcodeProjectError.indexPathsError("Failed to resolve index paths: \(error.localizedDescription)")
        }
    }

    public func getToolchain() -> XcodeToolchain {
        toolchain
    }

    public var currentProjectInfo: XcodeProjectBasicInfo? {
        currentProject
    }

    public func loadTargets(for scheme: String? = nil) async throws -> [XcodeTargetInfo] {
        guard let currentProject else {
            throw XcodeProjectError.invalidConfig("Project not loaded. Call loadProjectBasicInfo() first.")
        }

        let projectIdentifier = XcodeProjectIdentifier(rootURL: rootURL, projectLocation: currentProject.projectLocation)
        let commandBuilder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)

        let targetScheme = scheme ?? currentProject.schemeInfoList.first?.name
        guard let targetScheme else {
            throw XcodeProjectError.schemeNotFound("No scheme available for loading targets")
        }

        // Get build settings for the scheme to extract target information
        let buildCommand = commandBuilder.buildCommand(
            scheme: targetScheme,
            configuration: projectReference?.configuration ?? "Debug",
            options: XcodeBuildOptions.buildSettingsJSON
        )

        let (output, _) = try await toolchain.executeXcodeBuild(
            arguments: buildCommand,
            workingDirectory: rootURL
        )

        guard let data = output.data(using: .utf8) else {
            throw XcodeProjectError.buildSettingsNotFound
        }

        // Parse build settings to extract target information
        return try parseTargetsFromBuildSettings(data: data)
    }

    private func parseTargetsFromBuildSettings(data: Data) throws -> [XcodeTargetInfo] {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            return json.compactMap { targetSettings in
                guard let targetName = targetSettings["TARGET_NAME"] as? String else { return nil }

                let productType = targetSettings["PRODUCT_TYPE"] as? String
                let buildSettings = targetSettings.compactMapValues { $0 as? String }

                return XcodeTargetInfo(
                    name: targetName,
                    productType: productType,
                    buildSettings: buildSettings
                )
            }
        } catch {
            throw XcodeProjectError.dataParsingError("Failed to parse build settings: \(error.localizedDescription)")
        }
    }
}

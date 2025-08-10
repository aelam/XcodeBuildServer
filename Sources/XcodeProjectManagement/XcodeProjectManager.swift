//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger
import XcodeSchemeParser

public struct XcodeIndexPaths: Sendable {
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL

    public init(derivedDataPath: URL, indexStoreURL: URL, indexDatabaseURL: URL) {
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
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

public struct XcodeProjectInfo: Sendable {
    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
    public let xcodeListInfo: XcodeListInfo
    public let buildSettingsList: [XcodeBuildSettings]
    public let schemeInfoList: [XcodeSchemeInfo]
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL

    public init(
        rootURL: URL,
        projectLocation: XcodeProjectLocation,
        xcodeListInfo: XcodeListInfo,
        buildSettingsList: [XcodeBuildSettings],
        schemeInfoList: [XcodeSchemeInfo] = [],
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL
    ) {
        self.rootURL = rootURL
        self.projectLocation = projectLocation
        self.xcodeListInfo = xcodeListInfo
        self.buildSettingsList = buildSettingsList
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
    private let schemeLoader: XcodeSchemeLoader
    private let toolchain: XcodeToolchain
    private let xcodeProjectReference: XcodeProjectReference?

    private(set) var currentProject: XcodeProjectInfo?

    public init(
        rootURL: URL,
        xcodeProjectReference: XcodeProjectReference? = nil,
        toolchain: XcodeToolchain,
        locator: XcodeProjectLocator,
        schemeLoader: XcodeSchemeLoader = XcodeSchemeLoader()
    ) {
        self.rootURL = rootURL
        self.xcodeProjectReference = xcodeProjectReference
        self.toolchain = toolchain
        self.locator = locator
        self.schemeLoader = schemeLoader
    }

    public func initialize() async throws {
        try await toolchain.initialize()
    }

    public func resolveProjectInfo() async throws -> XcodeProjectInfo {
        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference
        )
        let projectIdentifier = XcodeProjectIdentifier(rootURL: rootURL, projectLocation: projectLocation)
        let settingsCommandBuilder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let settingsLoader = XcodeSettingsLoader(commandBuilder: settingsCommandBuilder, toolchain: toolchain)
        logger.debug("created settingsLoader, checking toolchain status...")
        logger.debug("about to call toolchain.getSelectedInstallation()...")
        let toolchainInstallation = await toolchain.getSelectedInstallation()
        logger.debug("got toolchain installation: \(toolchainInstallation?.path.path ?? "none")")
        logger.debug("toolchain installation check completed")
        logger.debug("getting xcodeListInfo...")
        let xcodeListInfo = try await settingsLoader.listInfo()
        logger.debug("got xcodeListInfo: \(xcodeListInfo)")

        // Load build settings and index paths with correct destination
        logger.debug("getting buildSettingsList...")
        let buildSettingsList = try await settingsLoader.loadBuildSettings(
            scheme: xcodeListInfo.schemes.first,
            target: nil,
            destination: nil
        )
        logger.debug("got buildSettingsList: \(buildSettingsList.count)")

        // Get index URLs using the first available scheme (shared per workspace)
        let indexPaths = try await loadIndexURLs(
            settingsLoader: settingsLoader,
            projectLocation: projectLocation,
            buildSettingsList: buildSettingsList
        )

        logger.debug("got indexPaths.derivedDataPath: \(indexPaths.derivedDataPath)")

        let filterSchemes: [String] = if let xcodeProjectReference, let scheme = xcodeProjectReference.scheme {
            [scheme]
        } else {
            []
        }
        let schemesToLoad = try schemeLoader.loadSchemes(
            from: projectLocation,
            filterBy: filterSchemes
        )
        logger.info("schemesToLoad.count: \(schemesToLoad.count)")

        // Validate loaded schemes
        try schemeLoader.validateSchemes(schemesToLoad)

        logger.info("resolve project successfully")
        logger.info("schemesToLoad: \(schemesToLoad.count)")
        return XcodeProjectInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            xcodeListInfo: xcodeListInfo,
            buildSettingsList: buildSettingsList,
            schemeInfoList: schemesToLoad,
            derivedDataPath: indexPaths.derivedDataPath,
            indexStoreURL: indexPaths.indexStoreURL,
            indexDatabaseURL: indexPaths.indexDatabaseURL
        )
    }

    private func loadIndexURLs(
        settingsLoader: XcodeSettingsLoader,
        projectLocation: XcodeProjectLocation,
        scheme: String? = nil,
        buildSettingsList: [XcodeBuildSettings]
    ) async throws -> XcodeIndexPaths {
        let (indexStoreURL, indexDatabaseURL) = try await settingsLoader.loadIndexingPaths(
            buildSettingsList: buildSettingsList
        )

        // Extract derived data path from index store URL (go up 2 levels from Index.noIndex/DataStore)
        // {Path/to/DerivedData}/{Project-hash}/Index.noIndex/DataStore
        let derivedDataPath = indexStoreURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return XcodeIndexPaths(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL
        )
    }

    public func getToolchain() -> XcodeToolchain {
        toolchain
    }

    /// Get the scheme loader for advanced scheme operations
    public func getSchemeLoader() -> XcodeSchemeLoader {
        schemeLoader
    }

    /// Get all runnable targets from loaded schemes
    public func getAllRunnableTargets() throws -> Set<String> {
        guard let currentProject else {
            throw XcodeProjectError.invalidConfig("Project not loaded. Call resolveProjectInfo() first.")
        }

        return schemeLoader.getAllRunnableTargets(from: currentProject.schemeInfoList)
    }

    /// Get all testable targets from loaded schemes
    public func getAllTestableTargets() throws -> Set<String> {
        guard let currentProject else {
            throw XcodeProjectError.invalidConfig("Project not loaded. Call resolveProjectInfo() first.")
        }

        return schemeLoader.getAllTestableTargets(from: currentProject.schemeInfoList)
    }

    /// Get the preferred scheme for a target
    public func getPreferredScheme(for targetName: String) throws -> XcodeSchemeInfo? {
        guard let currentProject else {
            throw XcodeProjectError.invalidConfig("Project not loaded. Call resolveProjectInfo() first.")
        }

        return schemeLoader.getPreferredScheme(for: targetName, from: currentProject.schemeInfoList)
    }

    private func parseTargetsFromBuildSettings(data: Data) throws -> [XcodeTargetInfo] {
        do {
            let string = String(data: data, encoding: .utf8)
            logger.debug("Build settings JSON: \(string ?? "(unprintable)")")
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

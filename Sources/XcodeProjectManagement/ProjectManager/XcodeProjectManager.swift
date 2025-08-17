//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger
import XcodeProj

public struct XcodeProjectPrimaryBuildSettings: Sendable {
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL
    public let configuration: String

    public init(derivedDataPath: URL, indexStoreURL: URL, indexDatabaseURL: URL, configuration: String) {
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.configuration = configuration
    }

    /// Custom flags for `xcodebuild -project {project} -target {target} SYSROOT={SYSROOT} -showBuildSettings -json`
    public var customFlagsMap: [String: String] {
        [
            "SYMROOT": derivedDataPath.path,
            // "DERIVED_DATA_PATH": derivedDataPath.path, // doesn't work
        ]
    }

    public var customFlags: [String] {
        customFlagsMap.map { "\($0.key)=\($0.value)" }
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
        xcodeProductType == .uiTestBundle || name.contains("UITest")
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

public actor XcodeProjectManager {
    public let rootURL: URL
    private let locator: XcodeProjectLocator
    private let toolchain: XcodeToolchain
    let settingsLoader: XcodeSettingsLoader

    private let xcodeProjectReference: XcodeProjectReference?
    private(set) var currentProject: XcodeProjectInfo?

    public init(
        rootURL: URL,
        xcodeProjectReference: XcodeProjectReference? = nil,
        toolchain: XcodeToolchain,
        locator: XcodeProjectLocator,
        settingsLoader: XcodeSettingsLoader
    ) {
        self.rootURL = rootURL
        self.xcodeProjectReference = xcodeProjectReference
        self.toolchain = toolchain
        self.locator = locator
        self.settingsLoader = settingsLoader
    }

    public func initialize() async throws {
        try await toolchain.initialize()
    }

    public func resolveProjectInfo() async throws -> XcodeProjectInfo {
        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference
        )
        _ = await toolchain.getSelectedInstallation()

        // Load containers for workspace projects to get actual targets
        let actualTargets = try await loadActualTargets(
            projectLocation: projectLocation
        )

        let schemeManager = XCSchemeManager()
        let schemes = try schemeManager.listSchemes(
            projectLocation: projectLocation,
            includeUserSchemes: true
        )

        let sortedSchemes = loadSchemsWithPriority(schemes: schemes, targets: actualTargets)
        let firstScheme = sortedSchemes.first
        guard let firstScheme else {
            throw XcodeProjectError.noSchemesFound("No schemes found in project at \(rootURL.path)")
        }
        // Load a build settings of any target to get DerivedData path
        let buildSettingsList = try await loadBuildSettings(
            rootURL: rootURL,
            projectLocation: projectLocation,
            scheme: firstScheme,
            settingsLoader: settingsLoader
        )

        // Get index URLs using the first available scheme (shared per workspace)
        let primaryBuildSettings = try await settingsLoader.loadPathsFromPrimayBuildSettings(
            buildSettingsList: buildSettingsList
        )

        let buildSettingsMap = try await settingsLoader.loadBuildSettingsMap(
            rootURL: rootURL,
            targets: actualTargets,
            customFlags: [
                "SYMROOT=/tmp/__A__/Build/Products",
                "OBJROOT=/tmp/__A__/Build/Intermediates.noindex",
//                "BUILD_DIR=/tmp/__A__/Build/Products"
//                "BUILD_ROOT=/tmp/__A__/Build/Products"
            ]
        )

        let buildSettingsForIndex = IndexSettingsGeneration.generate(
            rootURL: rootURL,
            buildSettingsMap: buildSettingsMap
        )

        // // Load buildSettingsForIndex for source file discovery
        // let buildSettingsForIndex = try await settingsLoader.loadBuildSettingsForIndex(
        //     rootURL: rootURL,
        //     targets: actualTargets,
        //     derivedDataPath: primaryBuildSettings.derivedDataPath
        // )
        // logger.debug("buildSettingsForIndex: \n\(buildSettingsForIndex)")

        return XcodeProjectInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            buildSettingsList: buildSettingsList,
            targets: actualTargets,
            schemes: [],
            derivedDataPath: primaryBuildSettings.derivedDataPath,
            indexStoreURL: primaryBuildSettings.indexStoreURL,
            indexDatabaseURL: primaryBuildSettings.indexDatabaseURL,
            buildSettingsForIndex: XcodeBuildSettingsForIndex()
        )
    }

    public func getToolchain() -> XcodeToolchain {
        toolchain
    }

    /// Load build settings with correct parameters based on project type
    private func loadBuildSettings(
        rootURL: URL,
        projectLocation: XcodeProjectLocation,
        scheme: XcodeScheme,
        configuration: String = "Debug",
        settingsLoader: XcodeSettingsLoader
    ) async throws -> [XcodeBuildSettings] {
        switch projectLocation {
        case .explicitWorkspace:
            try await settingsLoader.loadBuildSettings(
                rootURL: rootURL,
                project: .workspace(
                    workspaceURL: projectLocation.workspaceURL,
                    scheme: scheme.name
                ),
            )
        case let .implicitWorkspace(projectURL: projectURL, _), let .standaloneProject(projectURL):
            // For project, we can use target directly
            try await settingsLoader.loadBuildSettings(
                rootURL: rootURL,
                project: .project(
                    projectURL: projectURL,
                    buildMode: .scheme(scheme.name)
                )
            )
        }
    }
}

// MARK: - Utilities Extension

extension XcodeProjectManager {
    /// Resolve project path from workspace file reference
    func resolveProjectPath(from location: XCWorkspaceDataElementLocationType, workspaceURL: URL) -> URL? {
        let workspaceDir = workspaceURL.deletingLastPathComponent()

        switch location {
        case let .group(path):
            return workspaceDir.appendingPathComponent(path)
        case let .absolute(path):
            return URL(fileURLWithPath: path)
        case let .container(path):
            return workspaceDir.appendingPathComponent(path)
        case let .current(path):
            return workspaceDir.appendingPathComponent(path)
        case let .developer(path):
            // Developer directory path - this is more complex, but for now treat as relative
            return workspaceDir.appendingPathComponent(path)
        case let .other(_, path):
            // Fallback: treat as relative path
            return workspaceDir.appendingPathComponent(path)
        }
    }

    /// Load targets from a single project using XcodeProj
    private func loadTargetsFromProject(projectURL: URL) async throws -> [XcodeTarget] {
        try loadTargetsFromXcodeProj(projectPath: projectURL)
    }
}

//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger
import XcodeProj

/// Target information with complete project context
public struct XcodeTarget: Sendable, Hashable, Codable {
    public let name: String
    public let projectURL: URL
    public let projectName: String
    public let isFromWorkspace: Bool
    public let buildForTesting: Bool
    public let buildForRunning: Bool

    // Computed property for legacy compatibility
    public var targetName: String { name }

    public init(
        name: String,
        projectURL: URL,
        isFromWorkspace: Bool = false,
        buildForTesting: Bool = true,
        buildForRunning: Bool = true
    ) {
        self.name = name
        self.projectURL = projectURL
        self.projectName = projectURL.deletingPathExtension().lastPathComponent
        self.isFromWorkspace = isFromWorkspace
        self.buildForTesting = buildForTesting
        self.buildForRunning = buildForRunning
    }

    public var debugDescription: String {
        "XcodeTarget(name: \(name), projectURL: \(projectURL.path), isFromWorkspace: \(isFromWorkspace))"
    }
}

public typealias XcodeSchemeTargetInfo = XcodeTarget

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

        let schemeManager = XCSchemeManager()
        let schemes = try schemeManager.listSchemes(
            projectLocation: projectLocation,
            includeUserSchemes: true
        )

        let interestingSchemes = schemeManager.filterInterestingSchemes(
            schemes,
            filterOutTests: true,
            filterOutPods: true
        )

        let firstScheme = interestingSchemes.first ?? schemes.first
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
        let indexPaths = try await loadIndexURLs(
            settingsLoader: settingsLoader,
            projectLocation: projectLocation,
            buildSettingsList: buildSettingsList
        )

        // Load containers for workspace projects to get actual targets
        let actualTargets = try await loadActualTargets(
            projectLocation: projectLocation
        )

        // Load buildSettingsForIndex for source file discovery
        let buildSettingsForIndex = try await settingsLoader.loadBuildSettingsForIndex(
            rootURL: rootURL,
            targets: actualTargets,
            derivedDataPath: indexPaths.derivedDataPath
        )
        logger.debug("buildSettingsForIndex: \(buildSettingsForIndex)")

        return XcodeProjectInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            buildSettingsList: buildSettingsList,
            targets: actualTargets,
            schemes: [],
            derivedDataPath: indexPaths.derivedDataPath,
            indexStoreURL: indexPaths.indexStoreURL,
            indexDatabaseURL: indexPaths.indexDatabaseURL,
            buildSettingsForIndex: buildSettingsForIndex
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

        return XcodeIndexPaths(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL
        )
    }

    public func getToolchain() -> XcodeToolchain {
        toolchain
    }

    /// Load actual targets, handling both workspace and project cases
    private func loadActualTargets(
        projectLocation: XcodeProjectLocation
    ) async throws -> [XcodeTarget] {
        switch projectLocation {
        case .explicitWorkspace:
            // For workspace, load containers to get actual targets from projects
            return try await loadTargetsFromWorkspaceContainers(projectLocation: projectLocation)
        case let .implicitWorkspace(projectURL, _):
            // For project, load targets using XcodeProj
            let targetNames = try loadTargetsFromXcodeProj(projectPath: projectURL)
            return targetNames.map { targetName in
                XcodeTarget(name: targetName, projectURL: projectURL, isFromWorkspace: false)
            }
        case let .standaloneProject(projectURL):
            // For standalone project, load targets using XcodeProj
            let targetNames = try loadTargetsFromXcodeProj(projectPath: projectURL)
            return targetNames.map { targetName in
                XcodeTarget(name: targetName, projectURL: projectURL, isFromWorkspace: false)
            }
        }
    }

    /// Load targets from workspace containers using XcodeProj
    private func loadTargetsFromWorkspaceContainers(
        projectLocation: XcodeProjectLocation
    ) async throws -> [XcodeTarget] {
        guard case let .explicitWorkspace(workspaceURL) = projectLocation else {
            return []
        }

        do {
            // Use XcodeProj to parse workspace
            let workspace = try XCWorkspace(pathString: workspaceURL.path)
            var allTargets: [XcodeTarget] = []

            // Get all project references from workspace
            for element in workspace.data.children {
                if case let .file(fileRef) = element,
                   fileRef.location.path.hasSuffix(".xcodeproj") {
                    // Resolve project path relative to workspace
                    let projectPath = resolveProjectPath(
                        from: fileRef.location,
                        workspaceURL: workspaceURL
                    )

                    if let projectPath {
                        do {
                            let projectTargetNames = try loadTargetsFromXcodeProj(projectPath: projectPath)
                            let projectTargets = projectTargetNames.map { targetName in
                                XcodeTarget(name: targetName, projectURL: projectPath, isFromWorkspace: true)
                            }
                            allTargets.append(contentsOf: projectTargets)
                        } catch {
                            logger.error("Failed to load targets from project \(projectPath): \(error)")
                            // Continue with other projects
                        }
                    }
                }
            }

            logger.debug("Loaded \(allTargets.count) targets from workspace \(workspaceURL.path)")

            return allTargets
        } catch {
            logger.error("Failed to parse workspace \(workspaceURL.path): \(error)")
            return []
        }
    }

    /// Simple container parser using XcodeProj to get project URLs from workspace
    private func getProjectURLsFromWorkspace(workspaceURL: URL) -> [URL] {
        do {
            let workspace = try XCWorkspace(pathString: workspaceURL.path)
            var projectURLs: [URL] = []

            for element in workspace.data.children {
                if case let .file(fileRef) = element,
                   fileRef.location.path.hasSuffix(".xcodeproj") {
                    if let projectPath = resolveProjectPath(from: fileRef.location, workspaceURL: workspaceURL) {
                        projectURLs.append(projectPath)
                    }
                }
            }

            return projectURLs
        } catch {
            logger.error("Failed to parse workspace for project URLs: \(error)")
            return []
        }
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
                    scheme: scheme.name,
                    configuration: configuration
                ),
            )
        case let .implicitWorkspace(projectURL: projectURL, _), let .standaloneProject(projectURL):
            // For project, we can use target directly
            try await settingsLoader.loadBuildSettings(
                rootURL: rootURL,
                project: .project(
                    projectURL: projectURL,
                    buildMode: .scheme(scheme.name),
                    configuration: configuration
                )
            )
        }
    }
}

// MARK: - Utilities Extension

extension XcodeProjectManager {
    /// Load targets from XcodeProj directly
    private func loadTargetsFromXcodeProj(projectPath: URL) throws -> [String] {
        let project = try XcodeProj(pathString: projectPath.path)
        return project.pbxproj.nativeTargets.map(\.name)
    }

    /// Resolve project path from workspace file reference
    private func resolveProjectPath(from location: XCWorkspaceDataElementLocationType, workspaceURL: URL) -> URL? {
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
    private func loadTargetsFromProject(projectURL: URL) async throws -> [String] {
        try loadTargetsFromXcodeProj(projectPath: projectURL)
    }
}

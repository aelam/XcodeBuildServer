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

    public func resolveProjectInfo(additionalSchemes: [String] = []) async throws -> XcodeProjectInfo {
        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference
        )
        let projectIdentifier = XcodeProjectIdentifier(rootURL: rootURL, projectLocation: projectLocation)
        let settingsCommandBuilder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let settingsLoader = XcodeSettingsLoader(commandBuilder: settingsCommandBuilder, toolchain: toolchain)
        _ = await toolchain.getSelectedInstallation()
        let xcodeListInfo = try await settingsLoader.listInfo()

        // Load build settings and index paths with correct destination
        let buildSettingsList = try await settingsLoader.loadBuildSettings(
            scheme: xcodeListInfo.schemes.first,
            target: nil,
            destination: nil
        )

        // Get index URLs using the first available scheme (shared per workspace)
        let indexPaths = try await loadIndexURLs(
            settingsLoader: settingsLoader,
            projectLocation: projectLocation,
            buildSettingsList: buildSettingsList
        )

        var filterSchemes: [String] = []
        if let xcodeProjectReference, let scheme = xcodeProjectReference.scheme {
            filterSchemes.append(scheme)
        }
        filterSchemes.append(contentsOf: additionalSchemes)

        // Remove duplicates and ensure we have a non-empty list
        filterSchemes = Array(Set(filterSchemes))
        let schemesToLoad = try schemeLoader.loadSchemes(
            from: projectLocation,
            filterBy: filterSchemes
        )
        logger.info("schemesToLoad.count: \(schemesToLoad.count)")

        // Validate loaded schemes
        try schemeLoader.validateSchemes(schemesToLoad)

        let expectedTargets = Set(schemesToLoad.flatMap { scheme in
            scheme.targets
        })

        // Load buildSettingsForIndex for source file discovery
        let buildSettingsForIndex = try await loadBuildSettingsForIndexForTargets(
            expectedTargets: expectedTargets,
            settingsLoader: settingsLoader,
            derivedDataPath: indexPaths.derivedDataPath
        )

        return XcodeProjectInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            xcodeListInfo: xcodeListInfo,
            buildSettingsList: buildSettingsList,
            schemeInfoList: schemesToLoad,
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
}

extension XcodeProjectManager {
    /// Load build settings for multiple targets with proper project path resolution
    private func loadBuildSettingsForIndexForTargets(
        expectedTargets: Set<XcodeSchemeBuildActionEntry>,
        settingsLoader: XcodeSettingsLoader,
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        logger.debug("getting buildSettingsForIndex...")
        var mergedBuildSettings: XcodeBuildSettingsForIndex = [:]

        // Check if this is an explicit workspace and handle accordingly
        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference
        )

        switch projectLocation {
        case let .explicitWorkspace(workspaceURL):
            logger.debug("Processing explicit workspace for buildSettingsForIndex: \(workspaceURL.path)")
            return try await loadBuildSettingsFromWorkspace(
                workspaceURL: workspaceURL,
                derivedDataPath: derivedDataPath
            )

        case .implicitWorkspace:
            logger.debug("Processing implicit workspace for buildSettingsForIndex")
        }

        // 为每个 target 分别获取 buildSettingsForIndex
        for target in expectedTargets {
            let targetName = target.buildableReference.blueprintName
            logger.debug("🎯 Processing target: \(targetName)")
            logger.debug("  - ReferencedContainer: \(target.buildableReference.referencedContainer ?? "nil")")
            logger.debug("  - BuildForTesting: \(target.buildForTesting)")
            logger.debug("  - BuildForRunning: \(target.buildForRunning)")

            // 从 referencedContainer 提取 project 路径
            // 格式: "container:Hello.xcodeproj" 或 "container:../Hello.xcodeproj" 等
            var projectURL: URL?
            if let container = target.buildableReference.referencedContainer,
               container.hasPrefix("container:") {
                let relativePath = String(container.dropFirst("container:".count))

                // 解析相对路径，基于当前 workspace/project 的根目录
                if relativePath.hasPrefix("/") {
                    // 绝对路径（少见）
                    projectURL = URL(fileURLWithPath: relativePath)
                } else {
                    // 相对路径，基于 rootURL
                    projectURL = rootURL.appendingPathComponent(relativePath)
                }

                logger.debug("  - Resolved project URL: \(projectURL?.path ?? "nil")")
                logger.debug("  - Original container: \(container)")
            } else {
                logger.warning("  - ⚠️ Missing or invalid referencedContainer for target: \(targetName)")
            }

            do {
                // 使用 project + target 的方式获取 buildSettings
                let targetBuildSettings = try await settingsLoader.loadBuildSettingsForIndex(
                    projectURL: projectURL ?? rootURL, // 如果解析失败，使用 rootURL 作为 fallback
                    target: targetName,
                    derivedDataPath: derivedDataPath
                )

                // 合并到总的 buildSettings 中
                // 使用 projectPath/targetName 作为键，避免 workspace 中同名 target 冲突
                let projectKey = "\(projectURL?.path ?? rootURL.path)/\(targetName)"

                // 🔧 FIX: 合并 targetBuildSettings 到 mergedBuildSettings
                for (_, fileInfos) in targetBuildSettings {
                    // 只使用 projectKey (完整路径) 作为键，避免重复
                    mergedBuildSettings[projectKey] = fileInfos
                }

                if targetBuildSettings.isEmpty {
                    logger.warning("⚠️ Target buildSettings is empty for '\(targetName)'")
                }
            } catch {
                let msg = "❌ Failed to load buildSettings for target '\(targetName)': \(error)"
                logger.error(msg)

                // 尝试提供更多上下文信息
            }
        }
        return mergedBuildSettings
    }

    /// Load build settings from all projects in an explicit workspace
    private func loadBuildSettingsFromWorkspace(
        workspaceURL: URL,
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        var mergedBuildSettings: XcodeBuildSettingsForIndex = [:]

        let containerParser = XcodeContainerParser()
        let containerURLs = containerParser.getContainerURLs(from: workspaceURL)

        // Filter out the workspace itself, keep only .xcodeproj URLs
        let projectURLs = containerURLs.filter { $0.pathExtension == "xcodeproj" }

        // For each project, load all its targets
        for projectURL in projectURLs {
            do {
                let projectBuildSettings = try await loadBuildSettingsFromProject(
                    projectURL: projectURL,
                    derivedDataPath: derivedDataPath
                )

                // Merge into the main buildSettings
                for (key, value) in projectBuildSettings {
                    mergedBuildSettings[key] = value
                }

            } catch {
                logger.error("Failed to load build settings from project \(projectURL.path): \(error)")
                // Continue with other projects
            }
        }

        return mergedBuildSettings
    }

    /// Load build settings from a single project by listing all its targets
    private func loadBuildSettingsFromProject(
        projectURL: URL,
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        var projectBuildSettings: XcodeBuildSettingsForIndex = [:]

        // Create project-specific settings loader
        let projectIdentifier = XcodeProjectIdentifier(
            rootURL: projectURL.deletingLastPathComponent(),
            projectLocation: .implicitWorkspace(projectURL: projectURL, workspaceURL: projectURL)
        )
        let commandBuilder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let projectSettingsLoader = XcodeSettingsLoader(commandBuilder: commandBuilder, toolchain: toolchain)

        // Get list of all targets in the project
        let listInfo = try await projectSettingsLoader.listInfo()

        // Extract targets based on the kind of list info
        let targetNames: [String]
        switch listInfo.kind {
        case let .project(project):
            targetNames = project.targets
        case .workspace:
            logger.warning("Expected project info but got workspace info for \(projectURL.path)")
            return [:]
        }

        // Load build settings for each target
        for targetName in targetNames {
            do {
                let targetBuildSettings = try await projectSettingsLoader.loadBuildSettingsForIndex(
                    projectURL: projectURL,
                    target: targetName,
                    derivedDataPath: derivedDataPath
                )

                // Use project path + target name as key
                let targetKey = "\(projectURL.path)/\(targetName)"

                // Merge the target's build settings
                for (_, fileInfos) in targetBuildSettings {
                    projectBuildSettings[targetKey] = fileInfos
                    break // We only expect one entry per target
                }

            } catch {
                logger.error("Failed to load build settings for target '\(targetName)'" +
                    "in project \(projectURL.path): \(error)"
                )
            }
        }

        return projectBuildSettings
    }

    private func parseTargetsFromBuildSettings(data: Data) throws -> [XcodeTargetInfo] {
        do {
            _ = String(data: data, encoding: .utf8)
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

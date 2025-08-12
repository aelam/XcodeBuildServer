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
    public let buildSettingsForIndex: XcodeBuildSettingsForIndex?

    public init(
        rootURL: URL,
        projectLocation: XcodeProjectLocation,
        xcodeListInfo: XcodeListInfo,
        buildSettingsList: [XcodeBuildSettings],
        schemeInfoList: [XcodeSchemeInfo] = [],
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL,
        buildSettingsForIndex: XcodeBuildSettingsForIndex? = nil
    ) {
        self.rootURL = rootURL
        self.projectLocation = projectLocation
        self.xcodeListInfo = xcodeListInfo
        self.buildSettingsList = buildSettingsList
        self.schemeInfoList = schemeInfoList
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.buildSettingsForIndex = buildSettingsForIndex
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
        return try await resolveProjectInfo(additionalSchemes: [])
    }

    public func resolveProjectInfo(additionalSchemes: [String]) async throws -> XcodeProjectInfo {
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

        // 从所有schemes中收集unique targets进行验证
        logger.debug("📋 Collecting targets from \(schemesToLoad.count) loaded schemes:")
        for scheme in schemesToLoad {
            logger.debug("  Scheme: \(scheme.name)")
            logger.debug("    - Build targets: \(scheme.buildableTargets.map { $0.buildableReference.blueprintName })")
            logger.debug("    - Testable targets: \(scheme.testableTargets.map { $0.buildableReference.blueprintName })")
            logger.debug("    - All targets: \(scheme.targets.map { $0.buildableReference.blueprintName })")
        }

        let expectedTargets = Set(schemesToLoad.flatMap { scheme in
            scheme.targets
        })
        logger.debug("📊 Total unique targets collected: \(expectedTargets.count)")
        logger.debug("Target names: \(expectedTargets.map { $0.buildableReference.blueprintName })")

        // Load buildSettingsForIndex for source file discovery
        let buildSettingsForIndex = try await loadBuildSettingsForIndexForTargets(
            expectedTargets: expectedTargets,
            settingsLoader: settingsLoader,
            derivedDataPath: indexPaths.derivedDataPath
        )

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
        case .explicitWorkspace(let workspaceURL):
            logger.debug("Processing explicit workspace for buildSettingsForIndex: \(workspaceURL.path)")
            return try await loadBuildSettingsFromWorkspace(
                workspaceURL: workspaceURL,
                derivedDataPath: derivedDataPath
            )
            
        case .implicitWorkspace(_, _):
            logger.debug("Processing implicit workspace for buildSettingsForIndex")
            // Continue with existing logic for expectedTargets
        }

        // 为每个 target 分别获取 buildSettingsForIndex
        for target in expectedTargets {
            let targetName = target.buildableReference.blueprintName
            logger.debug("🎯 Processing target: \(targetName)")
            logger.debug("  - BlueprintIdentifier: \(target.buildableReference.blueprintIdentifier)")
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
                // targetBuildSettings 是 XcodeBuildSettingsForIndex 类型 [String: [String: XcodeFileBuildSettingInfo]]
                for (originalKey, fileInfos) in targetBuildSettings {
                    // 只使用 projectKey (完整路径) 作为键，避免重复
                    mergedBuildSettings[projectKey] = fileInfos
                    logger.debug("Stored buildSettings from '\(originalKey)' under key: '\(projectKey)'")
                }

                logger.debug("Using project key: \(projectKey) for target: \(targetName)")

                logger.debug("✅ Successfully loaded \(targetBuildSettings) target entries for '\(targetName)'")
                if targetBuildSettings.isEmpty {
                    logger.warning("⚠️ Target buildSettings is empty for '\(targetName)'")
                }
            } catch {
                let msg = "❌ Failed to load buildSettings for target '\(targetName)': \(error)"
                logger.error(msg)

                // 尝试提供更多上下文信息
                logger.debug("  Context: projectURL=\(projectURL?.path ?? "nil"), rootURL=\(rootURL.path)")
                logger.debug("  Target details: blueprintId=\(target.buildableReference.blueprintIdentifier)")

                // 继续处理其他 target，不要因为一个失败就停止
            }
        }

        logger.debug("===================\n got merged buildSettingsForIndex with\n \(mergedBuildSettings)")
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
        
        logger.debug("Found \(projectURLs.count) projects in workspace:")
        for projectURL in projectURLs {
            logger.debug("  - \(projectURL.path)")
        }
        
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
                
                logger.debug("Loaded \(projectBuildSettings.count) targets from project: \(projectURL.lastPathComponent)")
                
            } catch {
                logger.error("Failed to load build settings from project \(projectURL.path): \(error)")
                // Continue with other projects
            }
        }
        
        logger.debug("Total merged buildSettingsForIndex from workspace: \(mergedBuildSettings.count) targets")
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
        case .project(let project):
            targetNames = project.targets
        case .workspace:
            logger.warning("Expected project info but got workspace info for \(projectURL.path)")
            return [:]
        }
        
        logger.debug("Found \(targetNames.count) targets in project \(projectURL.lastPathComponent):")
        for targetName in targetNames {
            logger.debug("  - \(targetName)")
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
                    logger.debug("Stored buildSettings under key: '\(targetKey)'")
                    break // We only expect one entry per target
                }
                
            } catch {
                logger.error("Failed to load build settings for target '\(targetName)' in project \(projectURL.path): \(error)")
                // Continue with other targets
            }
        }
        
        return projectBuildSettings
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

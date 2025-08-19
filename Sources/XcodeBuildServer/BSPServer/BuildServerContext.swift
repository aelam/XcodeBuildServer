//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCConnection
import Logger
import XcodeProjectManagement

public enum BuildServerContextState: Sendable {
    case uninitialized
    case loaded(LoadedState)

    public struct LoadedState: Sendable {
        public let rootURL: URL
        public let config: XcodeBSPConfiguration?
        public let projectManager: XcodeProjectManager
        public let bspAdapter: XcodeToBSPAdapter
        public let xcodeProjectInfo: XcodeProjectInfo
    }
}

/// 构建服务器上下文 - 专注于 BSP 协议相关的业务逻辑
public actor BuildServerContext {
    private var state: BuildServerContextState = .uninitialized
    private let jsonDecoder = JSONDecoder()
    private var buildTasks: [String: Task<Void, Never>] = [:]
    private(set) var isIndexPrepared: Bool = false

    /// 项目管理器创建回调（由 BSPServerService 注入）
    private var onProjectManagerCreated: (@Sendable (XcodeProjectManager) async -> Void)?

    public init() {}

    /// 设置项目管理器创建回调（由服务层调用）
    public func setProjectManagerCreatedCallback(_ callback: @escaping @Sendable (XcodeProjectManager) async -> Void) {
        self.onProjectManagerCreated = callback
    }

    // Computed property to check if the context is properly loaded
    var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    // Safe accessor for loaded state (throws if not loaded)
    var loadedState: BuildServerContextState.LoadedState {
        get throws {
            guard case let .loaded(state) = state else {
                throw BuildServerError.invalidConfiguration("BuildServerContext not loaded - call loadProject() first")
            }
            return state
        }
    }

    public var rootURL: URL? {
        guard case let .loaded(state) = state else { return nil }
        return state.rootURL
    }

    public var config: XcodeBSPConfiguration? {
        guard case let .loaded(state) = state else { return nil }
        return state.config
    }

    func loadProject(
        rootURL: URL
    ) async throws {
        logger.info("Loading project at \(rootURL)")

        guard case .uninitialized = state else {
            return
        }

        // load bsp configuration with loader
        let configLoader = XcodeBSPConfigurationLoader(rootURL: rootURL)
        let config = try configLoader.loadConfiguration()
        if config == nil {
            logger.debug("No BSP config found, using project manager auto-discovery")
        }

        let xcodeToolchain = XcodeToolchain()
        // Create project manager (it will manage its own toolchain)
        let projectManager = XcodeProjectManager(
            rootURL: rootURL,
            xcodeProjectReference: config?.projectReference,
            toolchain: xcodeToolchain,
            locator: XcodeProjectLocator(),
            settingsLoader: XcodeSettingsLoader(
                commandBuilder: XcodeBuildCommandBuilder(),
                toolchain: xcodeToolchain
            )
        )

        try await projectManager.initialize()
        // Load project basic info (this will initialize toolchain internally)
        logger.debug(">>> Resolving project info")
        do {
            let xcodeProjectInfo = try await projectManager.resolveProjectInfo()
            logger.debug(">>> Project info resolved")

            // Initialize BSP adapter
            let bspAdapter = XcodeToBSPAdapter(
                xcodeProjectInfo: xcodeProjectInfo,
                xcodeToolchain: xcodeToolchain
            )

            self.state = .loaded(BuildServerContextState.LoadedState(
                rootURL: rootURL,
                config: config,
                projectManager: projectManager,
                bspAdapter: bspAdapter,
                xcodeProjectInfo: xcodeProjectInfo
            ))

            // 通知服务层项目管理器已创建，以便订阅状态变化
            if let callback = onProjectManagerCreated {
                await callback(projectManager)
            }

        } catch {
            logger.error(">>> Failed to resolve project info: \(error)")
            throw error
        }
    }
}

public extension BuildServerContext {
    // MARK: - BuildTarget Factory Methods

    func createBuildTargets() async throws -> [BuildTarget] {
        let state = try loadedState
        return try await state.bspAdapter.createBuildTargets()
    }

    func getProjectBasicInfo() throws -> XcodeProjectInfo {
        try loadedState.xcodeProjectInfo
    }

    func getProjectManager() throws -> XcodeProjectManager {
        try loadedState.projectManager
    }

    // MARK: - SourceKit Options Support

    func getCompileArguments(
        targetIdentifier: BuildTargetIdentifier,
        fileURI: String
    ) async throws -> [String] {
        let state = try loadedState

        let buildSettingsForIndex = state.xcodeProjectInfo.buildSettingsForIndex

        // Convert file URI to path
        let filePath = URL(string: fileURI)?.path ?? fileURI

        // Get file build settings from the index
        guard let targetSettings = buildSettingsForIndex[targetIdentifier.uri.stringValue] else {
            logger.warning("No build settings found for scheme: \(targetIdentifier.uri.stringValue)")
            return []
        }

        guard let fileBuildSettings = targetSettings[filePath] else {
            logger.debug("No specific build settings found for file: \(filePath)")
            // Try to get the first available file's settings as fallback
            if let firstFileSettings = targetSettings.values.first {
                logger.debug("Using fallback build settings from first available file")
                return getCompilerArgumentsForSourceKit(firstFileSettings)
            }
            return []
        }

        return getCompilerArgumentsForSourceKit(fileBuildSettings)
    }

    private func getCompilerArgumentsForSourceKit(_ fileBuildSettings: XcodeFileBuildSettingInfo) -> [String] {
        // Extract compiler arguments from file build settings
        guard let language = fileBuildSettings.languageDialect else {
            return []
        }
        if language.isSwift {
            return fileBuildSettings.swiftASTCommandArguments ?? []
        } else if language.isClang {
            return fileBuildSettings.clangASTCommandArguments ?? []
        }

        return []
    }

    func getWorkingDirectory() throws -> String? {
        let state = try loadedState
        return state.rootURL.path
    }

    func buildTargetForIndex(targets: [BuildTargetIdentifier]) throws {
        guard isIndexPrepared else {
            return //
        }
        let state = try loadedState
        let projectInfo = state.xcodeProjectInfo
        let projectManager = try getProjectManager()
        logger.debug("Building targets for index: \(targets)")
        guard !targets.isEmpty else {
            return
        }

        let taskKey = projectInfo.importantScheme.name

        // Cancel existing build task for this target if it exists
        if let existingTask = buildTasks[taskKey] {
            existingTask.cancel()
            logger.debug("Cancelled existing build task for target: \(taskKey)")
        }

        // Start new build task
        let buildTask = Task.detached { [weak self] in
            do {
                let result = try await projectManager.buildProject(
                    projectInfo: projectInfo
                )
                if result.exitCode == 0 {
                    await self?.markIndexPrepared()
                    logger.debug("Background build completed successfully for target \(taskKey)")
                } else {
                    logger.error("Background build failed for target \(taskKey) with exit code \(result.exitCode)")
                }

                logger.debug("Build result for target \(taskKey): \(result)")
            } catch {
                logger.error("Background build failed for target \(taskKey): \(error)")
            }

            // Clean up completed task
            await self?.removeBuildTask(for: taskKey)
        }

        buildTasks[taskKey] = buildTask
    }

    private func removeBuildTask(for taskKey: String) {
        buildTasks.removeValue(forKey: taskKey)
    }

    private func markIndexPrepared() {
        isIndexPrepared = true
    }

    func cancelAllBuildTasks() {
        for (taskKey, task) in buildTasks {
            task.cancel()
            logger.debug("Cancelled build task for target: \(taskKey)")
        }
        buildTasks.removeAll()
    }
}

//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

/// 加载状态枚举
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

public actor BuildServerContext {
    private var state: BuildServerContextState = .uninitialized
    private let jsonDecoder = JSONDecoder()

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
            locator: XcodeProjectLocator()
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
}

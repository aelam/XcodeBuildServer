//
//  BuildServerContext.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger
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

    // MARK: - SourceKit Options Support

    func getCompileArguments(
        target: BuildTargetIdentifier,
        fileURI: String
    ) async throws -> [String] {
        let state = try loadedState

        guard let buildSettingsForIndex = state.xcodeProjectInfo.buildSettingsForIndex else {
            logger.warning("No buildSettingsForIndex available")
            return []
        }

        // Extract scheme name from BuildTargetIdentifier
        // Expected format: "xcode:///ProjectName/SchemeName/TargetName"
        guard let targetScheme = extractSchemeFromBuildTarget(target) else {
            logger.warning("Could not extract scheme from build target: \(target.uri)")
            return []
        }

        // Convert file URI to path
        let filePath = URL(string: fileURI)?.path ?? fileURI

        // Get file build settings from the index
        guard let targetSettings = buildSettingsForIndex[targetScheme] else {
            logger.warning("No build settings found for scheme: \(targetScheme)")
            return []
        }

        guard let fileBuildSettings = targetSettings[filePath] else {
            logger.debug("No specific build settings found for file: \(filePath)")
            // Try to get the first available file's settings as fallback
            if let firstFileSettings = targetSettings.values.first {
                logger.debug("Using fallback build settings from first available file")
                return enhanceCompilerArgumentsForSourceKit(firstFileSettings.swiftASTCommandArguments ?? [])
            }
            return []
        }

        return enhanceCompilerArgumentsForSourceKit(fileBuildSettings.swiftASTCommandArguments ?? [])
    }

    /// Enhance compiler arguments with SourceKit-LSP specific parameters for better system framework support.
    private func enhanceCompilerArgumentsForSourceKit(_ baseArgs: [String]) -> [String] {
        var enhancedArgs = baseArgs

        // Only add flags that are universally supported and not likely to conflict
        let additionalFlags = ["-enable-bare-slash-regex"]

        for flag in additionalFlags where !enhancedArgs.contains(flag) {
            enhancedArgs.append(flag)
        }

        return enhancedArgs
    }

    func getWorkingDirectory() throws -> String? {
        let state = try loadedState
        return state.rootURL.path
    }

    func extractSchemeFromBuildTarget(_ target: BuildTargetIdentifier) -> String? {
        // Parse URI like "xcode:///ProjectName/SchemeName/TargetName"
        let uriString = target.uri.stringValue
        guard uriString.hasPrefix("xcode:///") else { return nil }

        let pathComponents = uriString.dropFirst("xcode:///".count).split(separator: "/")
        guard pathComponents.count >= 2 else { return nil }

        return String(pathComponents[1]) // SchemeName
    }
}

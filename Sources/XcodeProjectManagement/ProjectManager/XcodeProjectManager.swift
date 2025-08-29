//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger
import PathKit
import XcodeProj

/// Project Level buildSettings
public struct XcodeProjectProjectBuildSettings: Sendable, Codable, Hashable {
    public let derivedDataPath: URL // @see PathHash.derivedDataFullPath

    public var indexStoreURL: URL {
        derivedDataPath.appendingPathComponent("Index.noIndex/DataStore")
    }

    public var indexDatabaseURL: URL {
        derivedDataPath.appendingPathComponent("IndexDatabase.noIndex")
    }

    public var symRoot: URL {
        derivedDataPath.appendingPathComponent("Build/Products")
    }

    public var objRoot: URL {
        derivedDataPath.appendingPathComponent("Build/Intermediates.noindex")
    }

    public var sdkStatCacheDir: URL { // SDK_STAT_CACHE_DIR
        derivedDataPath.deletingLastPathComponent()
    }

    public var sdkStatCachePath: URL { // SDK_STAT_CACHE_PATH
        sdkStatCacheDir.appendingPathComponent("SDKStatCache")
    }

    public var moduleCachePath: URL { // parent of derivedDataPath
        derivedDataPath.deletingLastPathComponent()
            .appendingPathComponent("ModuleCache.noindex")
    }

    public var buildDir: URL {
        derivedDataPath.appendingPathComponent("Build/Products")
    }

    public init(derivedDataPath: URL) {
        self.derivedDataPath = derivedDataPath
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
    public let targetIdentifier: String
    public let name: String
    public let xcodeProductType: XcodeProductType
    public let buildSettings: [String: String]

    public init(
        targetIdentifier: String,
        name: String,
        xcodeProductType:
        XcodeProductType,
        buildSettings: [String: String]
    ) {
        self.targetIdentifier = targetIdentifier
        self.name = name
        self.xcodeProductType = xcodeProductType
        self.buildSettings = buildSettings
    }
}

public actor XcodeProjectManager {
    public let rootURL: URL
    let locator: XcodeProjectLocator
    let toolchain: XcodeToolchain
    let settingsLoader: XcodeSettingsLoader

    private var xcodeProjCache: [URL: XcodeProj] = [:]
    private var sourceFileMapCache: [String: [SourceItem]] = [:]

    func loadXcodeProjCache(projectURL: URL) -> XcodeProj? {
        if let cachedXcodeProj = xcodeProjCache[projectURL] {
            return cachedXcodeProj
        }
        let projectURLPath = Path(projectURL.path)
        let xcodeProj = try? XcodeProj(path: projectURLPath)
        xcodeProjCache[projectURL] = xcodeProj
        return xcodeProj
    }

//    // MARK: - State Management
//
//    private var projectState = ProjectState()
//    private var stateObservers: [WeakProjectStateObserver] = []
//
//    // MARK: - Project State Management
//
//    public func addStateObserver(_ observer: ProjectStateObserver) {
//        stateObservers.append(WeakProjectStateObserver(observer))
//    }
//
//    public func removeStateObserver(_ observer: ProjectStateObserver) {
//        stateObservers.removeAll { $0.observer === observer || $0.observer == nil }
//    }
//
//    private func notifyStateObservers(_ event: ProjectStateEvent) async {
//        stateObservers.removeAll { $0.observer == nil }
//
//        await withTaskGroup(of: Void.self) { group in
//            for weakObserver in stateObservers {
//                if let observer = weakObserver.observer {
//                    group.addTask {
//                        await observer.onProjectStateChanged(event)
//                    }
//                }
//            }
//        }
//    }
//
//    // MARK: - State Access Methods
//
//    public func getProjectState() -> ProjectState {
//        projectState
//    }

    private let xcodeProjectReference: XcodeProjectReference?
    public private(set) var xcodeProjectInfo: XcodeProjectInfo?
    public private(set) var xcodeProjectBaseInfo: XcodeProjectBaseInfo?

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

        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference
        )

        // Get project-level buildSettings without `xcodebuild`
        let derivedDataPath = PathHash.derivedDataFullPath(for: projectLocation.workspaceURL.path)
        let xcodeProjectBuildSettings = XcodeProjectProjectBuildSettings(derivedDataPath: derivedDataPath)

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
        let importantScheme = sortedSchemes.first
        guard let importantScheme else {
            throw XcodeProjectError.noSchemesFound("No schemes found in project at \(rootURL.path)")
        }

        let xcodeProjectBaseInfo = XcodeProjectBaseInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            xcodeProjectBuildSettings: xcodeProjectBuildSettings,
            importantScheme: importantScheme,
            xcodeTargets: actualTargets,
            schemes: schemes
        )
        self.xcodeProjectBaseInfo = xcodeProjectBaseInfo

        let xcodeProjectInfo = XcodeProjectInfo(
            baseProjectInfo: xcodeProjectBaseInfo,
            xcodeBuildSettingsForIndex: [:]
        )
        self.xcodeProjectInfo = xcodeProjectInfo
    }

//    public func resolveXcodeProjectInfo() async throws -> XcodeProjectInfo {
//        if let xcodeProjectInfo {
//            return xcodeProjectInfo
//        }
//
//        guard let xcodeProjectBaseInfo else {
//            fatalError("XcodeProjectInfo cannot be resolved before initialize()")
//        }
//
//        let xcodeProjectBuildSettings = xcodeProjectBaseInfo.xcodeProjectBuildSettings
//        let buildSettingsMap = try await settingsLoader.loadBuildSettingsMap(
//            rootURL: rootURL,
//            targets: xcodeProjectBaseInfo.xcodeTargets,
//            configuration: "Debug",
//            xcodeProjectBuildSettings: xcodeProjectBuildSettings,
//            customFlags: [
//                "SYMROOT=" + xcodeProjectBuildSettings.symRoot.path,
//                "OBJROOT=" + xcodeProjectBuildSettings.objRoot.path,
//                "SDK_STAT_CACHE_DIR=" + xcodeProjectBuildSettings.sdkStatCacheDir.path,
//                // "BUILD_DIR=/tmp/__A__/Build/Products"
//                // "BUILD_ROOT=/tmp/__A__/Build/Products"
//            ]
//        )
//
//        let buildSettingsForIndex = IndexSettingsGeneration.generate(
//            rootURL: rootURL,
//            xcodeProjectBuildSettings: xcodeProjectBaseInfo.xcodeProjectBuildSettings,
//            buildSettingsMap: buildSettingsMap
//        )
//
//        let xcodeProjectInfo = XcodeProjectInfo(
//            baseProjectInfo: xcodeProjectBaseInfo,
//            xcodeBuildSettingsForIndex: buildSettingsForIndex
//        )
//        self.xcodeProjectInfo = xcodeProjectInfo
//        return xcodeProjectInfo
//    }

    // MARK: - Build

    public func startBuild(target: String) async {
//        let buildTask = BuildTask(target: target)
//        projectState.activeBuildTasks[target] = buildTask
//        await notifyStateObservers(.buildStarted(target: target))
    }

    func completeBuild(target: String, duration: TimeInterval, success: Bool) async {
//        guard var buildTask = projectState.activeBuildTasks[target] else { return }
//        let duration = Date().timeIntervalSince(buildTask.startTime)
//        buildTask.status = .completed(success: success, duration: duration)
//        projectState.activeBuildTasks[target] = buildTask
//
//        await notifyStateObservers(.buildCompleted(target: target, success: success, duration: duration))

        // 清理完成的构建任务
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            self.cleanupBuildTask(target: target)
        }
    }

    public func failBuild(target: String, error: Error) async {
//        guard var buildTask = projectState.activeBuildTasks[target] else { return }
//        buildTask.status = .failed(error)
//        projectState.activeBuildTasks[target] = buildTask
//
//        await notifyStateObservers(.buildFailed(target: target, error: error))
    }

    private func cleanupBuildTask(target: String) {
//        projectState.activeBuildTasks.removeValue(forKey: target)
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
        try loadTargetsFromXcodeProj(projectURL: projectURL)
    }
}

//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Core
import Foundation
import Logger
import XcodeProj

public struct XcodeProjectProjectBuildSettings: Sendable, Codable, Hashable {
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL
    public let configuration: String
    public let sdkStatCacheDir: String // SDK_STAT_CACHE_DIR
    public let sdkStatCachePath: String // SDK_STAT_CACHE_PATH

    public init(
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL,
        configuration: String,
        sdkStatCacheDir: String,
        sdkStatCachePath: String
    ) {
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.configuration = configuration
        self.sdkStatCacheDir = sdkStatCacheDir
        self.sdkStatCachePath = sdkStatCachePath
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

public actor XcodeProjectManager: ProjectStatusPublisher {
    public let rootURL: URL
    let locator: XcodeProjectLocator
    let toolchain: XcodeToolchain
    let settingsLoader: XcodeSettingsLoader

    // MARK: - State Management

    private var projectState = ProjectState()
    private var stateObservers: [WeakProjectStateObserver] = []

    // MARK: - Status Observer Support (保持向后兼容)

    private var observers: [WeakProjectStatusObserver] = []

    public func addObserver(_ observer: ProjectStatusObserver) async {
        observers.append(WeakProjectStatusObserver(observer))
    }

    public func removeObserver(_ observer: ProjectStatusObserver) async {
        observers.removeAll { $0.observer === observer || $0.observer == nil }
    }

    func notifyObservers(_ event: ProjectStatusEvent) async {
        observers.removeAll { $0.observer == nil }

        await withTaskGroup(of: Void.self) { group in
            for weakObserver in observers {
                if let observer = weakObserver.observer {
                    group.addTask {
                        await observer.onProjectStatusChanged(event)
                    }
                }
            }
        }
    }

    // MARK: - Project State Management

    public func addStateObserver(_ observer: ProjectStateObserver) {
        stateObservers.append(WeakProjectStateObserver(observer))
    }

    public func removeStateObserver(_ observer: ProjectStateObserver) {
        stateObservers.removeAll { $0.observer === observer || $0.observer == nil }
    }

    private func notifyStateObservers(_ event: ProjectStateEvent) async {
        stateObservers.removeAll { $0.observer == nil }

        await withTaskGroup(of: Void.self) { group in
            for weakObserver in stateObservers {
                if let observer = weakObserver.observer {
                    group.addTask {
                        await observer.onProjectStateChanged(event)
                    }
                }
            }
        }
    }

    // MARK: - State Access Methods

    public func getProjectState() -> ProjectState {
        projectState
    }

    public func startBuild(target: String) async {
        let buildTask = BuildTask(target: target)
        projectState.activeBuildTasks[target] = buildTask
        await notifyStateObservers(.buildStarted(target: target))
    }

    public func completeBuild(target: String, success: Bool) async {
        guard var buildTask = projectState.activeBuildTasks[target] else { return }
        let duration = Date().timeIntervalSince(buildTask.startTime)
        buildTask.status = .completed(success: success, duration: duration)
        projectState.activeBuildTasks[target] = buildTask

        await notifyStateObservers(.buildCompleted(target: target, success: success, duration: duration))

        // 清理完成的构建任务
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            self.cleanupBuildTask(target: target)
        }
    }

    public func failBuild(target: String, error: Error) async {
        guard var buildTask = projectState.activeBuildTasks[target] else { return }
        buildTask.status = .failed(error)
        projectState.activeBuildTasks[target] = buildTask

        await notifyStateObservers(.buildFailed(target: target, error: error))
    }

    private func cleanupBuildTask(target: String) {
        projectState.activeBuildTasks.removeValue(forKey: target)
    }

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
        // 设置项目状态为加载中
        let oldState = projectState.projectLoadState
        projectState.projectLoadState = .loading(projectPath: rootURL.path)
        await notifyStateObservers(.projectLoadStateChanged(from: oldState, to: projectState.projectLoadState))

        let projectLocation = try locator.resolveProjectType(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference
        )
        _ = await toolchain.getSelectedInstallation()

        // Notify observers that project loading started (保持向后兼容)
        await notifyObservers(ProjectStatusEvent.projectLoaded(projectPath: rootURL.path))

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
        // Load a build settings of any target to get DerivedData path
        let buildSettingsList = try await loadBuildSettings(
            rootURL: rootURL,
            projectLocation: projectLocation,
            scheme: importantScheme,
            settingsLoader: settingsLoader
        )

        // Get index URLs using the first available scheme (shared per workspace)
        let projectBuildSettings = try await settingsLoader.loadPathsFromPrimayBuildSettings(
            buildSettingsList: buildSettingsList
        )

        let buildSettingsMap = try await settingsLoader.loadBuildSettingsMap(
            rootURL: rootURL,
            targets: actualTargets,
            customFlags: [
                "SYMROOT=" + projectBuildSettings.derivedDataPath.appendingPathComponent("Build/Products").path,
                "OBJROOT=" + projectBuildSettings.derivedDataPath.appendingPathComponent("Build/Intermediates.noindex")
                    .path,
                "SDK_STAT_CACHE_DIR=" + projectBuildSettings.derivedDataPath.deletingLastPathComponent().path,
                // "BUILD_DIR=/tmp/__A__/Build/Products"
                // "BUILD_ROOT=/tmp/__A__/Build/Products"
            ]
        )

        let buildSettingsForIndex = IndexSettingsGeneration.generate(
            rootURL: rootURL,
            projectBuildSettings: projectBuildSettings,
            buildSettingsMap: buildSettingsMap
        )

        let projectInfo = XcodeProjectInfo(
            rootURL: rootURL,
            projectLocation: projectLocation,
            buildSettingsList: buildSettingsList,
            projectBuildSettings: projectBuildSettings,
            importantScheme: importantScheme,
            targets: actualTargets,
            schemes: [],
            derivedDataPath: projectBuildSettings.derivedDataPath,
            indexStoreURL: projectBuildSettings.indexStoreURL,
            indexDatabaseURL: projectBuildSettings.indexDatabaseURL,
            buildSettingsForIndex: buildSettingsForIndex
        )
        self.currentProject = projectInfo
        return projectInfo
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

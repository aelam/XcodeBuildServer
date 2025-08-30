//
//  ProjectManager.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public protocol ProjectManager: AnyObject, Sendable {
    var rootURL: URL { get async }

    var projectInfo: ProjectInfo? { get async }

    func getProjectState() async -> ProjectState

    var projectType: String { get }

    func initialize() async throws

    // workspace/buildTargets
    func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget]

    // buildTarget/sources
    func getSourceFileList(targetIdentifiers: [BSPBuildTargetIdentifier]) async
        -> [SourcesItem]

    func getCompileArguments(
        targetIdentifier: String,
        sourceFileURL: URL
    ) async throws -> [String]

    func updateBuildGraph() async

    func buildIndex(for targets: [String]) async

    func startBuild(targets: [String]) async

    /// 添加项目状态观察者
    func addStateObserver(_ observer: ProjectStateObserver) async

    /// 移除项目状态观察者
    func removeStateObserver(_ observer: ProjectStateObserver) async
}

public struct ProjectInfo: Sendable {
    public let rootURL: URL
    public let name: String?
    public let targets: [ProjectTarget]
    public let buildSettingsForIndex: [String: [String: FileBuildSettingInfo]]
    public let projectBuildSettings: ProjectBuildSettings

    public init(
        rootURL: URL,
        name: String?,
        targets: [ProjectTarget],
        buildSettingsForIndex: [String: [String: FileBuildSettingInfo]],
        projectBuildSettings: ProjectBuildSettings
    ) {
        self.rootURL = rootURL
        self.name = name
        self.targets = targets
        self.buildSettingsForIndex = buildSettingsForIndex
        self.projectBuildSettings = projectBuildSettings
    }
}

public struct ProjectTarget: Sendable {
    public let targetIndentifier: String
    public let name: String

    public let isSourcesResolved: Bool
    public let isDependenciesResolved: Bool

    public let sourceFiles: [URL]
    public let dependencies: [ProjectTarget]

    public let productType: ProductType

    public init(
        targetIndentifier: String,
        name: String,
        isSourcesResolved: Bool,
        isDependenciesResolved: Bool,
        sourceFiles: [URL],
        dependencies: [ProjectTarget],
        productType: ProductType
    ) {
        self.targetIndentifier = targetIndentifier
        self.name = name
        self.isSourcesResolved = isSourcesResolved
        self.isDependenciesResolved = isDependenciesResolved
        self.sourceFiles = sourceFiles
        self.dependencies = dependencies
        self.productType = productType
    }
}

public struct ProjectBuildSettings: Sendable {
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL
    public let symRoot: URL // SYMROOT
    public let objRoot: URL // OBJROOT
    public let sdkStatCacheDir: URL // SDK_STAT_CACHE_DIR

    public init(derivedDataPath: URL) {
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = derivedDataPath
            .appendingPathComponent("Index.noIndex/DataStore")
        self.indexDatabaseURL = derivedDataPath
            .appendingPathComponent("IndexDatabase.noIndex")
        self.symRoot = derivedDataPath.appendingPathComponent("Build/Products")
        self.objRoot = derivedDataPath
            .appendingPathComponent("Build/Intermediates.noindex")
        self.sdkStatCacheDir = derivedDataPath.deletingLastPathComponent()
    }
}

public struct FileBuildSettingInfo: Sendable {
    public let language: Language?
    public let outputFilePath: String?
}

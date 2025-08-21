//
//  ProjectManager.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// 项目管理器协议 - 支持不同类型的项目管理后端
public protocol ProjectManager: AnyObject, Sendable {
    /// 项目根目录
    var rootURL: URL { get async }

    /// 当前项目信息
    var projectInfo: ProjectInfo? { get async }

    /// 项目类型
    var projectType: String { get }

    /// 初始化项目管理器
    func initialize() async throws

    /// 解析项目信息
    func resolveProjectInfo() async throws -> ProjectInfo

    /// 获取当前项目状态
    func getProjectState() async -> ProjectState

    func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget]

    func getSourceFileList(targetIdentifier: String) async -> [URL]

    func buildGraph() async

    func buildIndex(for targets: [String]) async

    func startBuild(targets: [String]) async

    /// 添加项目状态观察者
    func addStateObserver(_ observer: ProjectStateObserver) async

    /// 移除项目状态观察者
    func removeStateObserver(_ observer: ProjectStateObserver) async

    /// 获取指定文件的编译参数
    func getCompileArguments(targetIdentifier: String, sourceFileURL: String) async throws -> [String]
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

/// 抽象文件构建设置协议
public struct FileBuildSettingInfo: Sendable {
    public let languageDialectString: String?
    public let outputFilePath: String?
}

/// 抽象主要构建设置协议
public struct ProjectBuildSettings: Sendable {
    /// DerivedData 路径
    public let derivedDataPath: URL

    /// 索引存储路径
    public let indexStoreURL: URL

    /// 索引数据库路径
    public let indexDatabaseURL: URL

    /// 配置名称
    public let configuration: String

    public init(
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL,
        configuration: String
    ) {
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.configuration = configuration
    }
}

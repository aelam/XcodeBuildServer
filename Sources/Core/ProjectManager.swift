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
    var currentProject: (any ProjectInfo)? { get async }

    /// 项目类型
    nonisolated var projectType: BSPProjectType { get }

    /// 初始化项目管理器
    func initialize() async throws

    /// 解析项目信息
    func resolveProjectInfo() async throws -> any ProjectInfo

    /// 获取当前项目状态
    func getProjectState() async -> ProjectState

    func getSourceFileList() async -> [URI]

    /// 开始构建指定目标
    func startBuild(target: String) async

    /// 添加项目状态观察者
    func addStateObserver(_ observer: ProjectStateObserver) async

    /// 移除项目状态观察者
    func removeStateObserver(_ observer: ProjectStateObserver) async

    /// 获取指定文件的编译参数
    func getCompileArguments(targetIdentifier: String, fileURI: String) async throws -> [String]
}

/// 抽象项目信息协议
public protocol ProjectInfo: Sendable {
    /// 项目根目录
    var rootURL: URL { get }

    /// 项目名称
    var name: String { get }

    /// 项目类型
    var projectType: BSPProjectType { get }

    /// 构建目标列表
    var targets: [any ProjectTarget] { get async }

    /// 用于索引的构建设置
    var buildSettingsForIndex: [String: [String: any FileBuildSettingInfo]] { get async }

    /// 主要构建设置
    var projectBuildSettings: any ProjectBuildSettings { get async }
}

/// 抽象项目目标协议
public protocol ProjectTarget: Sendable {
    /// 目标名称
    var name: String { get }

    /// 产品类型
    var protocolProductType: ProductType { get }

    /// 支持的编程语言
    var supportedLanguages: Set<String> { get }

    /// 是否为测试目标
    var isTestTarget: Bool { get }

    /// 是否为可运行目标
    var isRunnableTarget: Bool { get }
}

/// 抽象文件构建设置协议
public protocol FileBuildSettingInfo: Sendable {
    /// 编程语言方言
    var languageDialectString: String? { get }

    /// 输出文件路径
    var outputFilePath: String? { get }
}

/// 抽象主要构建设置协议
public protocol ProjectBuildSettings: Sendable {
    /// DerivedData 路径
    var derivedDataPath: URL { get }

    /// 索引存储路径
    var indexStoreURL: URL { get }

    /// 索引数据库路径
    var indexDatabaseURL: URL { get }

    /// 配置名称
    var configuration: String { get }
}

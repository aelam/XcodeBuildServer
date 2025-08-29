////
////  SwiftPMProjectInfo.swift
////  SwiftPMProjectManagerProvider Module
////
////  Copyright © 2024 Wang Lun.
////
//
// // import Foundation
//
//// MARK: - SwiftPM 项目信息
//
///// SwiftPM项目信息实现
// public struct SwiftPMProjectInfo: ProjectInfo {
//    public let rootURL: URL
//    public let name: String
//    public let targets: [any ProjectTarget]
//    public let projectBuildSettings: any ProjectBuildSettings
//
//    public var buildSettingsForIndex: [String: [String: any FileBuildSettingInfo]] {
//        // TODO: 实现 SwiftPM 的构建设置
//        [:]
//    }
//
//    public init(
//        rootURL: URL,
//        name: String,
//        targets: [any ProjectTarget],
//        projectBuildSettings: any ProjectBuildSettings
//    ) {
//        self.rootURL = rootURL
//        self.name = name
//        self.targets = targets
//        self.projectBuildSettings = projectBuildSettings
//    }
// }
//
//// MARK: - SwiftPM 主要构建设置
//
///// SwiftPM主要构建设置实现
// public struct SwiftPMProjectBuildSettings: ProjectBuildSettings {
//    public let derivedDataPath: URL
//    public let indexStoreURL: URL
//    public let indexDatabaseURL: URL
//    public let configuration: String
//
//    public init(rootURL: URL, configuration: String = "debug") {
//        self.configuration = configuration
//
//        // SwiftPM 的构建路径通常在 .build 目录下
//        let buildPath = rootURL.appendingPathComponent(".build")
//        self.derivedDataPath = buildPath
//        self.indexStoreURL = buildPath.appendingPathComponent("index/DataStore")
//        self.indexDatabaseURL = buildPath.appendingPathComponent("index/Database")
//    }
// }
//
//// MARK: - SwiftPM 目标
//
///// SwiftPM目标实现
// public struct SwiftPMTarget: ProjectTarget {
//
//    public let name: String
//    public var isSourcesResolved: Bool
//    public var isDependenciesResolved: Bool
//
//    public let sourceFiles: [URL] = []
//    public var dependencies: [any ProjectTarget]
//
//    public let isTestTarget: Bool
//    public let isRunnableTarget: Bool
//
//    public init(
//        name: String,
//        isSourcesResolved: Bool,
//        isDependenciesResolved: Bool,
//        sourceFiles: [URL] = [],
//        dependencies: [any ProjectTarget],
//        isTestTarget: Bool = false,
//        isRunnableTarget: Bool = false
//    ) {
//        self.name = name
//        self.isSourcesResolved = isSourcesResolved
//        self.isDependenciesResolved = isDependenciesResolved
//        self.dependencies = dependencies
//
//        self.isTestTarget = isTestTarget
//        self.isRunnableTarget = isRunnableTarget
//    }
// }
//
//// MARK: - SwiftPM 文件构建设置
//
///// SwiftPM文件构建设置实现
// public struct SwiftPMFileBuildSettingInfo: FileBuildSettingInfo {
//    public let languageDialectString: String?
//    public let outputFilePath: String?
//
//    public init(languageDialectString: String? = nil, outputFilePath: String? = nil) {
//        self.languageDialectString = languageDialectString
//        self.outputFilePath = outputFilePath
//    }
// }
//
//// MARK: - 错误类型
//
///// SwiftPM项目错误
// public enum SwiftPMProjectError: Error, LocalizedError {
//    case invalidProject(String)
//    case packageParsingFailed(String)
//    case buildFailed(String)
//
//    public var errorDescription: String? {
//        switch self {
//        case let .invalidProject(message):
//            "Invalid SwiftPM project: \(message)"
//        case let .packageParsingFailed(message):
//            "Package parsing failed: \(message)"
//        case let .buildFailed(message):
//            "Build failed: \(message)"
//        }
//    }
// }

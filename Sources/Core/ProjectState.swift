//
//  ProjectState.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// 项目状态
public struct ProjectState: Sendable {
    /// 项目加载状态
    public var projectLoadState: ProjectLoadState = .uninitialized

    /// 活跃的构建任务
    public var activeBuildTasks: [String: BuildTask] = [:]

    /// 索引状态
    public var indexState: IndexState = .idle

    public init() {}
}

/// 项目加载状态
public enum ProjectLoadState: Sendable {
    case uninitialized
    case loading(projectPath: String)
    case loaded(projectInfo: any ProjectInfo)
    case failed(Error)
}

/// 构建任务
public struct BuildTask: Sendable {
    public let target: String
    public let startTime: Date
    public var status: BuildTaskStatus

    public init(target: String) {
        self.target = target
        self.startTime = Date()
        self.status = .running
    }
}

/// 构建任务状态
public enum BuildTaskStatus: Sendable {
    case running
    case completed(success: Bool, duration: TimeInterval)
    case failed(Error)
}

/// 索引状态
public enum IndexState: Sendable {
    case idle
    case preparing
    case indexing(progress: Double, message: String)
    case completed
    case failed(Error)
}

/// 项目状态事件
public enum ProjectStateEvent: Sendable {
    case projectLoadStateChanged(from: ProjectLoadState, to: ProjectLoadState)
    case buildStarted(target: String)
    case buildProgress(target: String, progress: Double, message: String)
    case buildCompleted(target: String, success: Bool, duration: TimeInterval)
    case buildFailed(target: String, error: Error)
    case indexStateChanged(from: IndexState, to: IndexState)
}

/// 项目状态观察者协议
public protocol ProjectStateObserver: AnyObject, Sendable {
    func onProjectStateChanged(_ event: ProjectStateEvent) async
}

/// 弱引用项目状态观察者包装器
public struct WeakProjectStateObserver {
    public weak var observer: ProjectStateObserver?

    public init(_ observer: ProjectStateObserver) {
        self.observer = observer
    }
}

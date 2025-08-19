//
//  ProjectState.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

// MARK: - Project State

public enum ProjectLoadState: Sendable {
    case uninitialized
    case loading(projectPath: String)
    case loaded(projectInfo: XcodeProjectInfo)
    case failed(Error)
}

public struct BuildTask: Sendable {
    public let target: String
    public let startTime: Date
    public var status: BuildStatus
    public var progress: Double = 0.0
    public var message: String = ""

    public enum BuildStatus: Sendable {
        case queued
        case building
        case completed(success: Bool, duration: TimeInterval)
        case failed(Error)
    }

    public init(target: String) {
        self.target = target
        self.startTime = Date()
        self.status = .building
    }
}

public enum IndexState: Sendable {
    case idle
    case preparing
    case indexing(progress: Double, message: String)
    case completed
    case failed(Error)
}

/// 项目状态 - 简单的状态数据结构
public struct ProjectState: Sendable {
    public var projectLoadState: ProjectLoadState = .uninitialized
    public var activeBuildTasks: [String: BuildTask] = [:]
    public var indexState: IndexState = .idle

    public init() {}
}

// MARK: - State Events

public enum ProjectStateEvent: Sendable {
    case projectLoadStateChanged(from: ProjectLoadState, to: ProjectLoadState)
    case buildStarted(target: String)
    case buildProgress(target: String, progress: Double, message: String)
    case buildCompleted(target: String, success: Bool, duration: TimeInterval)
    case buildFailed(target: String, error: Error)
    case indexStateChanged(from: IndexState, to: IndexState)
}

// MARK: - State Observer Protocol

public protocol ProjectStateObserver: AnyObject, Sendable {
    func onProjectStateChanged(_ event: ProjectStateEvent) async
}

// MARK: - Weak Observer Wrapper

class WeakProjectStateObserver {
    weak var observer: ProjectStateObserver?

    init(_ observer: ProjectStateObserver) {
        self.observer = observer
    }
}

//
//  ProjectStatusObserver.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// 项目状态变化事件
public enum ProjectStatusEvent: Sendable {
    case buildStarted(target: String)
    case buildProgress(target: String, progress: Double, message: String)
    case buildCompleted(target: String, success: Bool, duration: TimeInterval)
    case buildFailed(target: String, error: Error)
    case indexingStarted
    case indexingProgress(progress: Double)
    case indexingCompleted
    case projectLoaded(projectPath: String)
    case projectUnloaded
}

/// 项目状态观察者协议
public protocol ProjectStatusObserver: AnyObject, Sendable {
    func onProjectStatusChanged(_ event: ProjectStatusEvent) async
}

/// 项目状态发布者协议
public protocol ProjectStatusPublisher: AnyObject {
    func addObserver(_ observer: ProjectStatusObserver) async
    func removeObserver(_ observer: ProjectStatusObserver) async
}

/// 弱引用包装器，避免循环引用
public class WeakProjectStatusObserver {
    public weak var observer: ProjectStatusObserver?

    public init(_ observer: ProjectStatusObserver) {
        self.observer = observer
    }
}

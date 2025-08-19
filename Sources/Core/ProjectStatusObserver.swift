//
//  ProjectStatusObserver.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// 项目状态事件（向后兼容）
public enum ProjectStatusEvent: Sendable {
    case projectLoaded(projectPath: String)
    case buildStarted(target: String)
    case buildCompleted(target: String, success: Bool)
}

/// 项目状态观察者协议（向后兼容）
public protocol ProjectStatusObserver: AnyObject, Sendable {
    func onProjectStatusChanged(_ event: ProjectStatusEvent) async
}

/// 弱引用项目状态观察者包装器（向后兼容）
public struct WeakProjectStatusObserver {
    public weak var observer: ProjectStatusObserver?

    public init(_ observer: ProjectStatusObserver) {
        self.observer = observer
    }
}

/// 项目状态发布者协议（向后兼容）
public protocol ProjectStatusPublisher: AnyObject, Sendable {
    func addObserver(_ observer: ProjectStatusObserver) async
    func removeObserver(_ observer: ProjectStatusObserver) async
}

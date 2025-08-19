//
//  XcodeBSPMessageHandler.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCConnection
import os

/// Languages supported by XcodeBuildServer for Xcode projects
public let xcodeBuildServerSupportedLanguages: Set<Language> = [.swift, .objective_c, .objective_cpp, .c, .cpp]

/// BSP 消息处理器 - 专注于 BSP 协议实现
public final class XcodeBSPMessageHandler: ContextualMessageHandler, Sendable {
    public typealias Context = BSPServerService

    /// Languages supported by XcodeBuildServer for Xcode projects
    public let supportedLanguages: Set<Language> = xcodeBuildServerSupportedLanguages

    /// BSP 服务引用 - 使用 OSAllocatedUnfairLock 来保证线程安全
    private let bspServerServiceLock = OSAllocatedUnfairLock(initialState: nil as BSPServerService?)

    /// BSP 服务引用
    public var bspServerService: BSPServerService? {
        get {
            bspServerServiceLock.withLock { $0 }
        }
        set {
            bspServerServiceLock.withLock { $0 = newValue }
        }
    }

    public init() {}

    public func withContext<T>(_ operation: @escaping @Sendable (BSPServerService) async throws -> T) async rethrows
        -> T {
        guard let service = bspServerService else {
            fatalError("BSPServerService not set in XcodeBSPMessageHandler")
        }
        return try await operation(service)
    }

    /// 设置 BSP 服务引用
    public func setBSPServerService(_ service: BSPServerService) {
        self.bspServerService = service
    }

    /// 发送通知到客户端（通过服务层）
    public func sendNotification(_ notification: NotificationType) async throws {
        guard let service = bspServerService else {
            throw JSONRPCTransportError.transportClosed
        }
        try await service.sendNotification(notification)
    }
}

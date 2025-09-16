//
//  BSPMessageHandler.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCConnection
import Support

/// BSP 消息处理器 - 专注于 BSP 协议实现
public final class BSPMessageHandler: ContextualMessageHandler, Sendable {
    public typealias Context = BSPServerService

    /// BSP 服务引用 - 使用跨平台的线程安全锁
    private let bspServerServiceLock = CrossPlatformLock<BSPServerService?>(initialState: nil as BSPServerService?)

    /// BSP 服务引用
    public private(set) var bspServerService: BSPServerService? {
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
            fatalError("BSPServerService not set in BSPMessageHandler")
        }
        return try await operation(service)
    }

    /// 设置 BSP 服务引用
    public func setBSPServerService(_ service: BSPServerService) {
        self.bspServerService = service
    }
}

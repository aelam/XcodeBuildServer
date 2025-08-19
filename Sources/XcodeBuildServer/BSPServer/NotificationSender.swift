//
//  NotificationSender.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCConnection

/// 简单的通知发送接口 - 参考 JetBrains 的做法
public protocol NotificationSender {
    func send(_ notification: NotificationType) async throws
}

/// JSONRPCConnection 实现通知发送
extension JSONRPCConnection: NotificationSender {
    public func send(_ notification: NotificationType) async throws {
        try await send(notification: notification)
    }
}

/// 弱引用包装器，避免循环依赖 - JetBrains 最佳实践
public class WeakNotificationSender: NotificationSender, @unchecked Sendable {
    weak var connection: JSONRPCConnection?

    public init() {}

    public func send(_ notification: NotificationType) async throws {
        guard let connection else {
            throw JSONRPCTransportError.transportClosed
        }
        try await connection.send(notification: notification)
    }
}

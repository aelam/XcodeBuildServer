//
//  MessageRegistry.swift
//
//  Copyright © 2024 Wang Lun.
//

public final class MessageRegistry: Sendable {
    private let methodToRequest: [String: any RequestType.Type]
    private let methodToNotification: [String: any NotificationType.Type]

    public init(requests: [any RequestType.Type], notifications: [any NotificationType.Type]) {
        methodToRequest = Dictionary(uniqueKeysWithValues: requests.map { ($0.method(), $0) })
        methodToNotification = Dictionary(uniqueKeysWithValues: notifications.map { ($0.method(), $0) })
    }

    /// Returns the type of the message named `method`, or nil if it is unknown.
    public func requestType(for method: String) -> (any RequestType.Type)? {
        methodToRequest[method]
    }

    /// Returns the type of the message named `method`, or nil if it is unknown.
    public func notificationType(for method: String) -> NotificationType.Type? {
        methodToNotification[method]
    }
}
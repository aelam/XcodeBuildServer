//
//  MessageRegistry.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public final class MessageRegistry: Sendable {
    private let methodToRequest: [String: any RequestType.Type]
    private let methodToNotification: [String: any NotificationType.Type]

    public init(requests: [any RequestType.Type], notifications: [any NotificationType.Type]) {
        methodToRequest = Dictionary(uniqueKeysWithValues: requests.map { ($0.method, $0) })
        methodToNotification = Dictionary(uniqueKeysWithValues: notifications.map { ($0.method, $0) })
    }

    /// Returns the type of the message named `method`, or nil if it is unknown.
    public func requestType(for method: String) -> (any RequestType.Type)? {
        return methodToRequest[method]
    }

    /// Returns the type of the message named `method`, or nil if it is unknown.
    public func notificationType(for method: String) -> NotificationType.Type? {
        return methodToNotification[method]
    }
}

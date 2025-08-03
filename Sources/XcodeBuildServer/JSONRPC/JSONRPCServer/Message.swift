//
//  Message.swift
//
//  Copyright © 2024 Wang Lun.
//

public typealias RequestID = JSONRPCID

public protocol MessageType: Codable, Sendable {}

public protocol RequestType: Codable, Sendable {
    static func method() -> String
    func handle(
        handler: MessageHandler,
        id: RequestID
    ) async -> ResponseType?
}

public protocol ResponseType: MessageType {}

/// A notification, which must have a unique `method` name.
public protocol NotificationType: MessageType {
    /// The name of the request.
    static func method() -> String

    func handle(_ handler: MessageHandler) async throws
}

public struct VoidResponse: ResponseType, Hashable {
    public let id: JSONRPCID?
    public let jsonrpc: String
}

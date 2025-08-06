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

/// Enhanced request type that supports contextual message handlers.
/// This allows for type-safe context access without requiring downcasting.
public protocol ContextualRequestType: RequestType {
    /// The type of context this request requires.
    associatedtype RequiredContext: Sendable

    /// Handle the request with access to a contextual message handler.
    /// This method provides type-safe access to the build server context.
    ///
    /// - Parameters:
    ///   - handler: A contextual message handler that provides scoped context access
    ///   - id: The request ID for response correlation
    /// - Returns: The response for this request, or nil if the request cannot be handled
    func handle<Handler: ContextualMessageHandler>(
        handler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == RequiredContext
}

public protocol ResponseType: MessageType {}

/// A notification, which must have a unique `method` name.
public protocol NotificationType: MessageType {
    /// The name of the request.
    static func method() -> String

    func handle(_ handler: MessageHandler) async throws
}

/// Enhanced notification type that supports contextual message handlers.
/// This allows for type-safe context access without requiring downcasting.
public protocol ContextualNotificationType: NotificationType {
    /// The type of context this notification requires.
    associatedtype RequiredContext: Sendable

    /// Handle the notification with access to a contextual message handler.
    /// This method provides type-safe access to the build server context.
    ///
    /// - Parameter handler: A contextual message handler that provides scoped context access
    /// - Throws: Any error thrown by the notification handler or context access failures
    func handle<Handler: ContextualMessageHandler>(
        _ handler: Handler
    ) async throws where Handler.Context == RequiredContext
}

// MARK: - Response Types

public struct JSONRPCResponse: ResponseType {
    public let id: JSONRPCID?
    public let jsonrpc: String
    let response: JSONRPCResult

    public init(id: JSONRPCID?, jsonrpc: String = "2.0", response: JSONRPCResult) {
        self.id = id
        self.jsonrpc = jsonrpc
        self.response = response
    }
}

public struct JSONRPCErrorResponse: ResponseType {
    public let jsonrpc: String
    public let id: JSONRPCID?
    public let error: JSONRPCError

    public init(jsonrpc: String = "2.0", id: JSONRPCID?, error: JSONRPCError) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.error = error
    }
}

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

public struct VoidResponse: ResponseType, Hashable {
    public let id: JSONRPCID?
    public let jsonrpc: String
}

// MARK: - Default Implementations

public extension ContextualRequestType where RequiredContext == BuildServerContext {
    /// Default implementation that falls back to the original handle method.
    /// This provides backward compatibility for existing request handlers.
    func handle(
        handler: MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        // Try to use the contextual handler if available
        if let contextualHandler = handler as? XcodeBSPMessageHandler {
            return await handle(handler: contextualHandler, id: id)
        }

        // Return nil if not a contextual handler
        return nil
    }
}

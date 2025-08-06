//
//  Message.swift
//
//  Copyright © 2024 Wang Lun.
//

@_exported import JSONRPCServer

// MARK: - BSP-Specific Extensions

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

public extension ContextualNotificationType where RequiredContext == BuildServerContext {
    /// Default implementation that falls back to the original handle method.
    /// This provides backward compatibility for existing notification handlers.
    func handle(_ handler: MessageHandler) async throws {
        // Try to use the contextual handler if available
        if let contextualHandler = handler as? XcodeBSPMessageHandler {
            try await handle(contextualHandler)
        } else {
            throw JSONRPCError(
                code: -32601,
                message: "Contextual notification requires a contextual handler"
            )
        }
    }
}

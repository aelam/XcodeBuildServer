//
//  Message.swift
//
//  Copyright © 2024 Wang Lun.
//

import Logger

// MARK: - BSP-Specific Extensions

/// Default implementation for ContextualRequestType
/// This provides automatic bridging from RequestType to ContextualRequestType
public extension ContextualRequestType where RequiredContext == BuildServerContext {
    /// Default implementation that bridges RequestType to ContextualRequestType
    /// This automatically converts MessageHandler to XcodeBSPMessageHandler and calls the contextual method
    func handle(
        handler: MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        logger.debug("\(Self.self).handle(MessageHandler) - bridging to contextual handler")

        guard let contextualHandler = handler as? XcodeBSPMessageHandler else {
            logger.error("\(Self.self): handler is not XcodeBSPMessageHandler")
            return JSONRPCErrorResponse(
                id: id,
                error: JSONRPCError(
                    code: -32603,
                    message: "\(Self.self) requires contextual handler"
                )
            )
        }

        // Call the contextual version - explicitly call the generic method
        // We need to cast to the protocol type to ensure we call the right method
        return await self.handle(contextualHandler: contextualHandler, id: id)
    }
}

public extension ContextualNotificationType where RequiredContext == BuildServerContext {
    /// Default implementation that falls back to the original handle method.
    /// This provides backward compatibility for existing notification handlers.
    func handle(handler: MessageHandler) async throws {
        // Try to use the contextual handler if available
        if let contextualHandler = handler as? XcodeBSPMessageHandler {
            try await handle(contextualHandler: contextualHandler)
        } else {
            throw JSONRPCError(
                code: -32601,
                message: "Contextual notification requires a contextual handler"
            )
        }
    }
}

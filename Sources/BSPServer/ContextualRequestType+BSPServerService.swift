//
//  ContextualRequestType+BSPServerService.swift
//  sourcekit-bsp
//
//  Copyright © 2024 Wang Lun.
//

import JSONRPCConnection

// MARK: - Default Implementations for Contextual Protocols

/// Provides default implementations for ContextualRequestType in the sourcekit-bsp context
public extension ContextualRequestType where RequiredContext == BSPServerService {
    /// Default implementation that bridges from MessageHandler to BSPMessageHandler
    func handle(handler: MessageHandler, id: RequestID) async -> ResponseType? {
        guard let contextualHandler = handler as? BSPMessageHandler else {
            return nil
        }
        return await handle(contextualHandler: contextualHandler, id: id)
    }
}

/// Provides default implementations for ContextualNotificationType in the sourcekit-bsp context
public extension ContextualNotificationType where RequiredContext == BSPServerService {
    /// Default implementation that bridges from MessageHandler to BSPMessageHandler
    func handle(handler: MessageHandler) async throws {
        guard let contextualHandler = handler as? BSPMessageHandler else {
            return
        }
        try await handle(contextualHandler: contextualHandler)
    }
}

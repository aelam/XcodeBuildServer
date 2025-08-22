//
//  ContextualRequestType+BSPServerService.swift
//  XcodeBuildServer
//
//  Copyright © 2024 Wang Lun.
//

import JSONRPCConnection

// MARK: - Default Implementations for Contextual Protocols

/// Provides default implementations for ContextualRequestType in the XcodeBuildServer context
public extension ContextualRequestType where RequiredContext == BSPServerService {
    /// Default implementation that bridges from MessageHandler to BSPMessageHandler
    func handle(handler: MessageHandler, id: RequestID) async -> ResponseType? {
        guard let contextualHandler = handler as? BSPMessageHandler else {
            return nil
        }
        return await handle(contextualHandler: contextualHandler, id: id)
    }
}

/// Provides default implementations for ContextualNotificationType in the XcodeBuildServer context
public extension ContextualNotificationType where RequiredContext == BSPServerService {
    /// Default implementation that bridges from MessageHandler to BSPMessageHandler
    func handle(handler: MessageHandler) async throws {
        guard let contextualHandler = handler as? BSPMessageHandler else {
            return
        }
        try await handle(contextualHandler: contextualHandler)
    }
}

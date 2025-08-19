//
import JSONRPCConnection

//  CancelRequestNotification.swift
//
//  Copyright 2024 Wang Lun.
//

import Logger

public struct CancelRequestNotification: ContextualNotificationType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "$/cancelRequest"
    }

    public struct Params: Codable, Sendable {
        public let id: RequestID
    }

    public let params: Params

    // Base NotificationType implementation
    public func handle(handler: MessageHandler) async throws {
        guard let contextualHandler = handler as? XcodeBSPMessageHandler else {
            return
        }
        return try await handle(contextualHandler: contextualHandler)
    }

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler
    ) async throws where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            logger.info("Cancel request received for ID: \(params.id)")
        }
    }
}

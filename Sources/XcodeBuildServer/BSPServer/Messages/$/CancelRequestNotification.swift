//
//  CancelRequestNotification.swift
//
//  Copyright 2024 Wang Lun.
//

import Logger

public struct CancelRequestNotification: ContextualNotificationType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "$/cancelRequest"
    }

    public struct Params: Codable, Sendable {
        public let id: RequestID
    }

    public let params: Params

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler
    ) async throws where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { _ in
            logger.info("Cancel request received for ID: \(params.id)")
        }
    }
}

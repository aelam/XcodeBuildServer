//
//  BuildTaskStartNotification.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

import JSONRPCConnection
import Logger

public struct BuildTaskStartNotification: ContextualNotificationType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "build/taskStart"
    }

    // MARK: - ContextualNotificationType Implementation

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler
    ) async throws where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            // build/taskStart notification handler
            // This notification is sent when a build task is started
            logger.debug("Received build/taskStart notification")
        }
    }
}

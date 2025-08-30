//
//  OnBuildInitializedNotification.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

/**
 {
 "method": "build\/initialized",
 "jsonrpc": "2.0",
 "params": {

 }
 }
 */
import JSONRPCConnection
import Logger

public struct OnBuildInitializedNotification: ContextualNotificationType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "build/initialized"
    }

    // MARK: - ContextualNotificationType Implementation

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler
    ) async throws where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            // build/initialized notification handler
            // This notification is sent after build/initialize request is processed
            logger.debug("Received build/initialized notification")
        }
    }
}

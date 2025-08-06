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

public struct OnBuildInitializedNotification: ContextualNotificationType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "build/initialized"
    }

    public func handle<Handler: ContextualMessageHandler>(_ handler: Handler) async throws
        where Handler.Context == BuildServerContext {
        await handler.withContext { _ in
            // build/initialized notification handler
            // This notification is sent after build/initialize request is processed
            logger.debug("Received build/initialized notification")
        }
    }
}

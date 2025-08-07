//
//  BuildLogMessageRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/24.
//

public struct BuildLogMessageRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "build/logMessage"
    }

    let id: JSONRPCID

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { _ in
            BuildLogMessageResponse(
                jsonrpc: "2.0",
                id: self.id,
                message: "",
                level: ""
            )
        }
    }
}

struct BuildLogMessageResponse: ResponseType, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?

    /// The log message.
    let message: String

    /// The log level.
    let level: String
}

//
//  BuildShutdownRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public final class BuildShutdownRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String { "build/shutdown" }

    public func handle<Handler: ContextualMessageHandler>(
        handler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await handler.withContext { _ in
            BuildShutdownResponse(
                jsonrpc: "2.0",
                id: id,
                message: "",
                level: ""
            )
        }
    }
}

struct BuildShutdownResponse: ResponseType {
    let jsonrpc: String
    let id: JSONRPCID?

    /// The log message.
    let message: String

    /// The log level.
    let level: String
}

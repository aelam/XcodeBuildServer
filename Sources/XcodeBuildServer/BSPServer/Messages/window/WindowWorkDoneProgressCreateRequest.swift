//
//  WindowWorkDoneProgressCreateRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/23.
//

public struct WindowWorkDoneProgressCreateRequest: ContextualRequestType {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "window/workDoneProgress/create"
    }

    struct Params: Codable, Sendable {
        let token: ProgressToken
    }

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { _ in
            WindowWorkDoneProgressCreateResponse(jsonrpc: "2.0", id: id)
        }
    }
}

struct WindowWorkDoneProgressCreateResponse: ResponseType, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?
}

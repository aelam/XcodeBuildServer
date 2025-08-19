//
import JSONRPCConnection

//  WindowWorkDoneProgressCreateRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/23.
//

public struct WindowWorkDoneProgressCreateRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "window/workDoneProgress/create"
    }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

    public struct Params: Codable, Sendable {
        let token: ProgressToken
    }

    // Base RequestType implementation
    public func handle(handler: MessageHandler, id: RequestID) async -> ResponseType? {
        guard let contextualHandler = handler as? XcodeBSPMessageHandler else {
            return nil
        }
        return await handle(contextualHandler: contextualHandler, id: id)
    }

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            WindowWorkDoneProgressCreateResponse(jsonrpc: "2.0", id: id)
        }
    }
}

struct WindowWorkDoneProgressCreateResponse: ResponseType, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?
}

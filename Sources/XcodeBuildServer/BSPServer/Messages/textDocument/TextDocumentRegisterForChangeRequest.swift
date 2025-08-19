//
import JSONRPCConnection

//  TextDocumentRegisterForChangeRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/**
 {
 "params": {
 "uri" : "file:///Users/ST22956/work-vscode/Hello/Hello/World/World.swift",
 "action" : "register"
 },
 "method":"textDocument/registerForChanges",
 "id":3,
 "jsonrpc":"2.0"
 }
 */

public struct TextDocumentRegisterForChangeRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "textDocument/registerForChanges"
    }

    public struct Params: Codable, Sendable {
        let uri: String
        let action: RegisterAction
    }

    public enum RegisterAction: String, Hashable, Codable, Sendable {
        case register
        case unregister
    }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

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
            TextDocumentRegisterForChangeResponse(
                jsonrpc: jsonrpc,
                id: id,
                result: nil
            )
        }
    }
}

public struct TextDocumentRegisterForChangeResponse: ResponseType, Hashable {
    public struct Result: Codable, Hashable, Sendable {
        /// The compiler options required for the requested file.
        public let compilerArguments: [String]

        /// The working directory for the compile command.
        public let workingDirectory: String?
    }

    public let jsonrpc: String
    public let id: JSONRPCID?
    public let result: Result?
}

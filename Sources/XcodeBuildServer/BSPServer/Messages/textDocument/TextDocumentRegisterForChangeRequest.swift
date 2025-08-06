//
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
    public typealias RequiredContext = BuildServerContext

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

    public func handle<Handler: ContextualMessageHandler>(
        handler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await handler.withContext { context in
            guard let fileURL = URL(string: params.uri) else {
                return TextDocumentRegisterForChangeResponse(
                    jsonrpc: jsonrpc,
                    id: id,
                    result: nil
                )
            }

            if params.action == .register {
                let arguments = await context.getCompileArguments(fileURI: fileURL.path)
                let workingDirectory = await context.rootURL?.path
                return TextDocumentRegisterForChangeResponse(
                    jsonrpc: jsonrpc,
                    id: id,
                    result: TextDocumentRegisterForChangeResponse.Result(
                        compilerArguments: arguments,
                        workingDirectory: workingDirectory
                    )
                )
            }
            return TextDocumentRegisterForChangeResponse(
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

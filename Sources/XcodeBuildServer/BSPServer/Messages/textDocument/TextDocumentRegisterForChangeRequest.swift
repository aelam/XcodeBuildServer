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

public struct TextDocumentRegisterForChangeRequest: RequestType, @unchecked Sendable {
    public struct Params: Codable {
        let uri: String
        let action: RegisterAction
    }

    public enum RegisterAction: String, Hashable, Codable, Sendable {
        case register
        case unregister
    }

    public static var method: String { "textDocument/registerForChanges" }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

    public func handle(
        handler: any MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        guard let handler = handler as? XcodeBSPMessageHandler else {
            return nil
        }

        guard let fileURL = URL(string: params.uri) else {
            return nil
        }

        if params.action == .register {
            let arguments = await handler.getCompileArguments(fileURI: fileURL.path)
            let workingDirectory = await handler.getRootURL()?.path
            return TextDocumentRegisterForChangeResponse(
                jsonrpc: jsonrpc,
                id: id,
                result:
                    TextDocumentRegisterForChangeResponse.Result(
                        compilerArguments: arguments,
                        workingDirectory: workingDirectory
                    )
            )
        } else {}
        return nil
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

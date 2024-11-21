//
//  TextDocumentRegisterForChangeRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/18.
//

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
    struct Params: Codable {
        let uri: String
        let action: RegisterAction
    }

    public enum RegisterAction: String, Hashable, Codable, Sendable {
      case register = "register"
      case unregister = "unregister"
    }

    public static var method: String { "textDocument/registerForChanges" }
    
    public let id: JSONRPCID
    public let jsonrpc: String

    public func handle(
        _ handler: any MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        guard handler is XcodeBSPMessageHandler else {
            return nil
        }
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
    
    public let id: JSONRPCID?
    public let result: Result?
    public let jsonrpc: String
}


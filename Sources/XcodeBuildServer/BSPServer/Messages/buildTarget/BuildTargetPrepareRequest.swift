//
//  buildTargetPrepareRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

/// https://github.com/swiftlang/sourcekit-lsp/blob/87b928540200708a198d829c4ad1bac37b1a5d69/Contributor%20Documentation/Implementing%20a%20BSP%20server.md#supporting-background-indexing

struct BuildTargetPrepareRequest: RequestType, Sendable {
    static var method: String { "buildTarget/prepare" }
    let targets: [String]
    
    func handle(_ handler: any MessageHandler, id: RequestID) async -> (any ResponseType)? {
        nil
    }
}

struct BuildTargetPrepareResponse: ResponseType, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?

    let targets: [String]
}

//
//  BuildTargetPrepareRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

/// https://github.com/swiftlang/sourcekit-lsp/blob/87b928540200708a198d829c4ad1bac37b1a5d69/Contributor%20Documentation/Implementing%20a%20BSP%20server.md#supporting-background-indexing

struct BuildTargetPrepareRequest: ContextualRequestType, Sendable {
    typealias RequiredContext = BuildServerContext

    static func method() -> String {
        "buildTarget/prepare"
    }

    let targets: [String]

    func handle<Handler: ContextualMessageHandler>(
        handler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await handler.withContext { context in
            BuildTargetPrepareResponse(
                jsonrpc: "2.0",
                id: id,
                targets: [""]
            )
        }
    }
}

struct BuildTargetPrepareResponse: ResponseType, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?

    let targets: [String]
}

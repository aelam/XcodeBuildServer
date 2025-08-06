//
//  WorkspaceWaitForBuildSystemUpdates.swift
//
//  Copyright © 2024 Wang Lun.
//

/// https://github.com/swiftlang/sourcekit-lsp/blob/87b928540200708a198d829c4ad1bac37b1a5d69/Contributor%20Documentation/BSP%20Extensions.md
///

public struct WorkspaceWaitForBuildSystemUpdatesRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "workspace/waitForBuildSystemUpdates"
    }

    public struct Params: Codable, Sendable {
        public let targets: [String]
    }

    public func handle<Handler: ContextualMessageHandler>(
        handler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await handler.withContext { _ in
            WorkspaceWaitForBuildSystemUpdatesResponse(
                jsonrpc: "2.0", id: id
            )
        }
    }
}

struct WorkspaceWaitForBuildSystemUpdatesResponse: ResponseType, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?
}

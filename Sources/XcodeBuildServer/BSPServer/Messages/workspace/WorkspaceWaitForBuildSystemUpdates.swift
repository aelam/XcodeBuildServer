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
    }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: VoidParams

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { _ in
            WorkspaceWaitForBuildSystemUpdatesResponse(
                jsonrpc: "2.0",
                id: id
            )
        }
    }
}

typealias WorkspaceWaitForBuildSystemUpdatesResponse = VoidResponse

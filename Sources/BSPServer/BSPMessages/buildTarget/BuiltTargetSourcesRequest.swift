//
//  BuiltTargetSourcesRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection

struct BuiltTargetSourcesRequest: ContextualRequestType, Sendable {
    typealias RequiredContext = BSPServerService

    static func method() -> String {
        "buildTarget/sources"
    }

    struct Params: Codable, Sendable {
        let targets: [BSPBuildTargetIdentifier]
    }

    let params: Params

    func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BSPServerService {
        await contextualHandler.withContext { context in
            guard let sourcesItemList = try? await context.getSourcesItems(targetIds: params.targets) else {
                logger.error("failed to create sourcesItem List")
                return JSONRPCErrorResponse(
                    id: id,
                    error: JSONRPCError(
                        code: -32603,
                        message: "failed to create sourcesItem List"
                    )
                )
            }

            return BuildTargetSourcesResponse(id: id, items: sourcesItemList)
        }
    }
}

public struct BuildTargetSourcesResponse: ResponseType, Hashable {
    public let id: JSONRPCID?
    public let jsonrpc: String
    public let result: BuildTargetSourcesResult

    public init(id: JSONRPCID? = nil, jsonrpc: String = "2.0", items: [SourcesItem]) {
        self.id = id
        self.jsonrpc = jsonrpc
        self.result = BuildTargetSourcesResult(items: items)
    }
}

public struct BuildTargetSourcesResult: Codable, Hashable, Sendable {
    public let items: [SourcesItem]

    public init(items: [SourcesItem]) {
        self.items = items
    }
}

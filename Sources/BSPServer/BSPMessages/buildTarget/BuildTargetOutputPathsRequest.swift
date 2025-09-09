//
//  BuildTargetOutputPathsRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection

/// https://build-server-protocol.github.io/docs/specification.html
/// https://github.com/microsoft/build-server-for-gradle
public struct BuildTargetOutputPathsRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "buildTarget/outputPaths"
    }

    public struct Params: Codable, Sendable {
        /// The build targets to prepare for background indexing
        public let targets: [BSPBuildTargetIdentifier]
        public let originId: String?

        public init(targets: [BSPBuildTargetIdentifier], originId: String? = nil) {
            self.targets = targets
            self.originId = originId
        }
    }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            logger.debug("get outputs of targets: \(params.targets)")
            return BuildTargetOutputPathsResponse(
                jsonrpc: jsonrpc,
                id: id,
                result: BuildTargetOutputPathsResult(originId: params.originId, statusCode: .error)
            )
        }
    }
}

public struct BuildTargetOutputPathsResponse: ResponseType, Hashable {
    public let jsonrpc: String
    public let id: JSONRPCID?
    public let result: BuildTargetOutputPathsResult

    public init(jsonrpc: String = "2.0", id: JSONRPCID? = nil, result: BuildTargetOutputPathsResult) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
    }
}

public struct BuildTargetOutputPathsResult: Codable, Hashable, Sendable {
    /** An optional request id to know the origin of this report. */
    public let originId: String?
    /** A status code for the execution. */
    public let statusCode: StatusCode?

    public init(originId: String? = nil, statusCode: StatusCode? = nil) {
        self.originId = originId
        self.statusCode = statusCode
    }
}

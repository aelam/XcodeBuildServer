//
//  BuildTargetCleanCacheRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection

/// The build target prepare request is sent from the client to the server to
/// prepare build targets for background indexing. This method is typically
/// used to ensure that all necessary build artifacts are available for
/// language servers to provide accurate semantic information.
///
/// - Important: This method is used to support background indexing.
///   See https://forums.swift.org/t/extending-functionality-of-build-server-protocol-with-sourcekit-lsp/74400
public struct BuildTargetCleanCacheRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "buildTarget/cleanCache"
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
            logger.debug("clean cache targets: \(params.targets)")

            return JSONRPCErrorResponse(
                id: id,
                error: JSONRPCError(
                    code: -32603,
                    message: "Not implemented",
                )
            )
        }
    }
}

public struct BuildTargetCleanCacheResponse: ResponseType, Hashable {
    public let jsonrpc: String
    public let id: JSONRPCID?
    public let result: BuildTargetCleanCacheResult

    public init(jsonrpc: String = "2.0", id: JSONRPCID? = nil, result: BuildTargetCleanCacheResult) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
    }
}

public struct BuildTargetCleanCacheResult: Codable, Hashable, Sendable {
    /** An optional request id to know the origin of this report. */
    public let originId: String?
    /** A status code for the execution. */
    public let statusCode: StatusCode?

    public init(originId: String? = nil, statusCode: StatusCode? = nil) {
        self.originId = originId
        self.statusCode = statusCode
    }
}

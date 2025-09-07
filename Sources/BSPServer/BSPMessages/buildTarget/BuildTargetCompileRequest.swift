//
//  BuildTargetCompileRequest.swift
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
public struct BuildTargetCompileRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "buildTarget/compile"
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
            let targetURIs = params.targets.map(\.uri.stringValue)
            logger.debug("Compile targets: \(targetURIs)")
            // TODO: compile targets here
            return BuildTargetCompileResponse(
                jsonrpc: jsonrpc,
                id: id,
                result: BuildTargetCompileResult(originId: params.originId, statusCode: 0)
            )
        }
    }
}

public struct BuildTargetCompileResponse: ResponseType, Hashable {
    public let jsonrpc: String
    public let id: JSONRPCID?
    public let result: BuildTargetCompileResult

    public init(jsonrpc: String = "2.0", id: JSONRPCID? = nil, result: BuildTargetCompileResult) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
    }
}

public struct BuildTargetCompileResult: Codable, Hashable, Sendable {
    /** An optional request id to know the origin of this report. */
    public let originId: String?
    /** A status code for the execution. */
    public let statusCode: Int?

    /** Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified. */
    // public let dataKind: CompileResultDataKind?

    /** A field containing language-specific information, like products
     * of compilation or compiler-specific metadata the client needs to know. */
    // data?: CompileResultData

    public init(originId: String? = nil, statusCode: Int? = nil) {
        self.originId = originId
        self.statusCode = statusCode
    }
}

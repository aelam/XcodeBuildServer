//
//  BuildTargetPrepareRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// The build target prepare request is sent from the client to the server to
/// prepare build targets for background indexing. This method is typically
/// used to ensure that all necessary build artifacts are available for
/// language servers to provide accurate semantic information.
///
/// - Important: This method is used to support background indexing.
///   See https://forums.swift.org/t/extending-functionality-of-build-server-protocol-with-sourcekit-lsp/74400
public struct BuildTargetPrepareRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "buildTarget/prepare"
    }

    public struct Params: Codable, Sendable {
        /// The build targets to prepare for background indexing
        public let targets: [BuildTargetIdentifier]

        public init(targets: [BuildTargetIdentifier]) {
            self.targets = targets
        }
    }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { _ in
            // Prepare build targets for background indexing
            // This may include ensuring compiler outputs, index databases, etc. are up to date
            let targetURIs = params.targets.map(\.uri.stringValue)
            logger.debug("Preparing build targets for background indexing: \(targetURIs)")

            // Currently returns success status, actual implementation may need to perform compilation or other
            // preparation work

            return BuildTargetPrepareResponse(
                jsonrpc: jsonrpc,
                id: id
            )
        }
    }
}

typealias BuildTargetPrepareResponse = VoidResponse

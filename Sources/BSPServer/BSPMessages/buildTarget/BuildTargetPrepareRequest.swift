//
//  BuildTargetPrepareRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCConnection

/// The build target prepare request is sent from the client to the server to
/// prepare build targets for background indexing. This method is typically
/// used to ensure that all necessary build artifacts are available for
/// language servers to provide accurate semantic information.
///
/// - Important: This method is used to support background indexing.
///   See https://forums.swift.org/t/extending-functionality-of-build-server-protocol-with-sourcekit-lsp/74400
public struct BuildTargetPrepareRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

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
    ) async -> ResponseType? where Handler.Context == BSPServerService {
        await contextualHandler.withContext { context in
            // Prepare build targets for background indexing
            // This may include ensuring compiler outputs, index databases, etc. are up to date
            let targetURIs = params.targets.map(\.uri.stringValue)
            logger.debug("Preparing build targets for background indexing: \(targetURIs)")
            do {
                // trigger xcodebuild to build the selected scheme in background
                try await context.buildTargetForIndex(targets: params.targets)
                logger.debug("Successfully started build preparation for targets")
            } catch {
                logger.error("Failed to start build targets preparation: \(error)")
            }
            return BuildTargetPrepareResponse(
                jsonrpc: jsonrpc,
                id: id
            )
        }
    }
}

typealias BuildTargetPrepareResponse = VoidResponse

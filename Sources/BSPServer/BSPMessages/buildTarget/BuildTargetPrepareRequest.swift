//
//  BuildTargetPrepareRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection

/// https://build-server-protocol.github.io/docs/specification.html
/// https://github.com/microsoft/build-server-for-gradle
public struct BuildTargetPrepareRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "buildTarget/prepare"
    }

    public struct Params: Codable, Sendable {
        /// The build targets to prepare for background indexing
        public let targets: [BSPBuildTargetIdentifier]

        public init(targets: [BSPBuildTargetIdentifier]) {
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

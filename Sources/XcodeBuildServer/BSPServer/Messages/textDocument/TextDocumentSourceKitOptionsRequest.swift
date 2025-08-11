//
//  TextDocumentSourceKitOptionsRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

/**
 * Example textDocument/sourceKitOptions request:
 * {
 *   "jsonrpc": "2.0",
 *   "method": "textDocument/sourceKitOptions",
 *   "params": {
 *     "textDocument": { "uri": "file:///path/to/source.swift" },
 *     "target": { "uri": "xcode:///ProjectName/SchemeName/TargetName" },
 *     "language": "swift"
 *   }
 * }
 */

/**
 * Example response format:
 * {
 *   "compilerArguments": [
 *     "-module-name", "Hello",
 *     "-Onone",
 *     "-enforce-exclusivity=checked",
 *     "/path/to/source.swift",
 *     "-DDEBUG",
 *     "-sdk", "/Applications/Xcode.app/.../iPhoneOS.sdk",
 *     "-target", "arm64-apple-ios18.0",
 *     "-index-store-path", "/path/to/IndexStore"
 *   ],
 *   "workingDirectory": "/path/to/project"
 * }
 */

/// The `textDocument/sourceKitOptions` request is sent from the client to the server to query for the list of
/// compiler options necessary to compile a specific file in the given target.
///
/// The build settings are considered up-to-date and can be cached by SourceKit-LSP until a
/// `buildTarget/didChange` notification is sent for the requested target.
///
/// The request may return `nil` if no build settings are available for the file in the given target.

public struct TextDocumentSourceKitOptionsRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "textDocument/sourceKitOptions"
    }

    public struct Params: Codable, Sendable {
        /// The URI of the document to get options for
        public var textDocument: TextDocumentIdentifier

        /// The target for which the build setting should be returned.
        ///
        /// A source file might be part of multiple targets and might have different compiler arguments in those two
        /// targets,
        /// thus the target is necessary in this request.
        public var target: BuildTargetIdentifier

        /// The language with which the document was opened in the editor.
        public var language: Language
    }

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { context in
            do {
                // Get compile arguments for the specific file using BSP target
                let compilerArguments = try await context.getCompileArguments(
                    target: params.target,
                    fileURI: params.textDocument.uri.stringValue
                )

                // Get working directory from context
                let workingDirectory = try await context.getWorkingDirectory()

                // Create and return the response with the actual data
                let result = TextDocumentSourceKitOptionsResponse.Result(
                    compilerArguments: compilerArguments,
                    workingDirectory: workingDirectory
                )

                return TextDocumentSourceKitOptionsResponse(
                    id: id,
                    jsonrpc: "2.0",
                    result: result
                )
            } catch {
                logger.error("Failed to get sourceKit options: \(error)")

                // Return response with empty result on error
                return TextDocumentSourceKitOptionsResponse(
                    id: id,
                    jsonrpc: "2.0",
                    result: nil
                )
            }
        }
    }
}

public struct TextDocumentSourceKitOptionsResponse: ResponseType, Hashable {
    public struct Result: Codable, Hashable, Sendable {
        /// The compiler options required for the requested file.
        public let compilerArguments: [String]

        /// The working directory for the compile command.
        public let workingDirectory: String?
    }

    public let id: JSONRPCID?
    public let jsonrpc: String
    public let result: Result?
}

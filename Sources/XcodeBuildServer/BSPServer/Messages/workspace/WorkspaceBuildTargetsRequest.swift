//
//  WorkspaceBuildTargetsRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

///
///
///   {
/// "method":"workspace/buildTargets","id":2,"jsonrpc":"2.0","params":{}}

///
public struct WorkspaceBuildTargetsRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "workspace/buildTargets"
    }

    public struct Params: Codable, Sendable {}

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params?

    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { context in
            do {
                let allBuildTargets = try await context.createBuildTargets()
                return WorkspaceBuildTargetsResponse(
                    id: id,
                    jsonrpc: "2.0",
                    targets: allBuildTargets
                )
            } catch {
                logger.error("Failed to get build targets: \(error)")

                // 提供更友好的错误信息，特别是对于未初始化的情况
                let errorMessage: String
                if error.localizedDescription.contains("BuildServerContext not loaded") {
                    errorMessage = "Build server not initialized. Please send 'build/initialize' request first."
                } else {
                    errorMessage = "Failed to get build targets: \(error.localizedDescription)"
                }

                return JSONRPCErrorResponse(
                    id: id,
                    error: JSONRPCError(
                        code: -32002, // LSP ServerNotInitialized error code
                        message: errorMessage
                    )
                )
            }
        }
    }
}

public struct WorkspaceBuildTargetsResponse: ResponseType, Sendable {
    public let id: JSONRPCID?
    public let jsonrpc: String
    public let result: WorkspaceBuildTargetsResult

    public init(id: JSONRPCID?, jsonrpc: String = "2.0", targets: [BuildTarget]) {
        self.id = id
        self.jsonrpc = jsonrpc
        self.result = WorkspaceBuildTargetsResult(targets: targets)
    }
}

public struct WorkspaceBuildTargetsResult: Codable, Sendable {
    public let targets: [BuildTarget]

    public init(targets: [BuildTarget]) {
        self.targets = targets
    }
}

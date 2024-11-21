//
//  WorkspaceWaitForBuildSystemUpdates.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/22.
//

/// https://github.com/swiftlang/sourcekit-lsp/blob/87b928540200708a198d829c4ad1bac37b1a5d69/Contributor%20Documentation/BSP%20Extensions.md
/// 

public struct WorkspaceWaitForBuildSystemUpdatesRequest: RequestType, @unchecked Sendable {
    public static var method: String { "workspace/waitForBuildSystemUpdates" }
    
    public struct Params: Codable {
        public var targets: [String]
    }
    
    public func handle(
        _ handler: MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        fatalError()
    }
}


//
//  WorkspaceWaitForBuildSystemUpdates.swift
//
//  Copyright © 2024 Wang Lun.
//

/// https://github.com/swiftlang/sourcekit-lsp/blob/87b928540200708a198d829c4ad1bac37b1a5d69/Contributor%20Documentation/BSP%20Extensions.md
///

public struct WorkspaceWaitForBuildSystemUpdatesRequest: RequestType, @unchecked Sendable {
    public static var method: String { "workspace/waitForBuildSystemUpdates" }

    public struct Params: Codable {
        public var targets: [String]
    }

    public func handle(
        _: MessageHandler,
        id _: RequestID
    ) async -> ResponseType? {
        fatalError()
    }
}

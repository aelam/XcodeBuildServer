//
//  WorkspaceDidChangeWatchedFilesNotification.swift
//
//  Copyright © 2024 Wang Lun.
//

public struct WorkspaceDidChangeWatchedFilesNotification: NotificationType, Sendable {
    public static func method() -> String {
        "workspace/didChangeWatchedFiles"
    }
    
    public struct Params: Codable {
        public var targets: [String]
    }

    public func handle(
        _: MessageHandler
    ) async {
        fatalError("WorkspaceDidChangeWatchedFilesNotification not implemented")
    }
}

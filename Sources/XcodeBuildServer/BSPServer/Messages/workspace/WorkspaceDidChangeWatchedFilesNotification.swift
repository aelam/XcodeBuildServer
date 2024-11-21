//
//  WorkspaceDidChangeWatchedFilesNotification.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

public struct WorkspaceDidChangeWatchedFilesNotification: NotificationType, @unchecked Sendable {
    public static var method: String { "workspace/didChangeWatchedFiles" }
    
    public struct Params: Codable {
        public var targets: [String]
    }
    
    public func handle(
        _ handler: MessageHandler
    ) async {
        fatalError()
    }
}



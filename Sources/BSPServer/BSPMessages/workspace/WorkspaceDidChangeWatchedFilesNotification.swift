//

//  WorkspaceDidChangeWatchedFilesNotification.swift
//
//  Copyright © 2024 Wang Lun.
//

import JSONRPCConnection
import Logger

public struct WorkspaceDidChangeWatchedFilesNotification: ContextualNotificationType, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "workspace/didChangeWatchedFiles"
    }

    public struct Params: Codable, Sendable {
        public let targets: [String]
    }

    public func handle(
        contextualHandler: some ContextualMessageHandler
    ) async throws {
        logger.debug("WorkspaceDidChangeWatchedFilesNotification received")
        // if xcodeproj file version is < 13.0 skip
        // Handle the notification, e.g., update the workspace state or notify clients
        // if context.xcodeprojFileVersion < "13.0" {
        //     logger.info("Skipping WorkspaceDidChangeWatchedFilesNotification handling for Xcode < 13.0")
        //     return
        // }
    }
}

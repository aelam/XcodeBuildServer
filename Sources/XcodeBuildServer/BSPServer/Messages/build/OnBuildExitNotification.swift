//
//  OnBuildExitNotification.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

/// Like the language server protocol, a notification to ask the
/// server to exit its process. The server should exit with success
/// code 0 if the shutdown request has been received before;
/// otherwise with error code 1.
public struct OnBuildExitNotification: NotificationType, Sendable {
    public typealias RequiredContext = BuildServerContext
    public static func method() -> String {
        "build/exit"
    }

    public func handle(_: MessageHandler) async {}
}

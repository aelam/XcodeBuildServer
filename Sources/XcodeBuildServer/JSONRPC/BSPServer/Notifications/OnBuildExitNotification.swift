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
public final class OnBuildExitNotification: Notification, @unchecked Sendable {
    public class override var method: String { "build/exit" }

    public override func handle(_ handler: MessageHandler) async {
        
    }
}

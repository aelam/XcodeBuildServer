//
//  OnBuildInitializedNotification.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

/**
 {
     "method": "build\/initialized",
     "jsonrpc": "2.0",
     "params": {

     }
 }
 */

public struct OnBuildInitializedNotification: NotificationType, @unchecked Sendable {
    public static var method: String { "build/initialized" }

    public func handle(_: MessageHandler) async {}
}

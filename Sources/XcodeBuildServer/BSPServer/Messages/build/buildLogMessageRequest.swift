//
//  buildLogMessageRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/24.
//

public struct BuildLogMessageRequest: RequestType, Sendable {
    public static func method() -> String {
        "build/logMessage"
    }
    
    let id: JSONRPCID

    public func handle(
        handler: any MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        guard let _ = handler as? XcodeBSPMessageHandler else {
            return nil
        }
        return nil
    }
}

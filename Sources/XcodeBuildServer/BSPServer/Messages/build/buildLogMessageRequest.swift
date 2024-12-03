//
//  buildLogMessageRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/24.
//

public struct BuildLogMessageRequest: RequestType, @unchecked Sendable {
    
    public static var method: String { "build/logMessage" }
    
    let id: JSONRPCID
    
    public func handle(
        _ handler: any MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        guard let handler = handler as? XcodeBSPMessageHandler else {
            return nil
        }
        return nil
    }
}

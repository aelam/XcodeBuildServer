//
//  WorkspaceBuildTargets.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

public struct WorkspaceBuildTargetsRequest: RequestType, @unchecked Sendable {
    public static var method: String { "workspace/buildTargets" }
    
    public func handle(
        _ handler: MessageHandler,
        id: RequestID
    ) async -> ResponseType? {
        fatalError()
    }
}



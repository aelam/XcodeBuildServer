//
//  BuildShutdownRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public final class BuildShutdownRequest: RequestType, Sendable {
    public static func method() -> String { "build/shutdown" }

    public func handle(
        handler: any MessageHandler,
        id: RequestID
    ) async -> (any ResponseType)? {
        fatalError("BuildShutdownRequest not implemented")
    }
}

//
//  BuildShutdownRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public final class BuildShutdownRequest: Request, @unchecked Sendable {
    override public static var method: String { "build/shutdown" }

    override public func handle(
        handler: MessageHandler,
        id: RequestID
    ) async -> ResponseType {
        fatalError("BuildShutdownRequest not implemented")
    }
}

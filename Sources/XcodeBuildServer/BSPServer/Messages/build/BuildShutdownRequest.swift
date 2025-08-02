//
//  BuildShutdownRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public final class BuildShutdownRequest: Request, @unchecked Sendable {
    override public class var method: String { "build/shutdown" }

    override public func handle(
        _: MessageHandler,
        id _: RequestID
    ) async -> ResponseType {
        fatalError("BuildShutdownRequest not implemented")
    }
}

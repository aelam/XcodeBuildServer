//
//  WindowWorkDoneProgressCreateRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/23.
//

public struct WindowWorkDoneProgressCreateRequest: RequestType {
    public static func method() -> String {
        "window/workDoneProgress/create"
    }

    struct Params: Codable, Sendable {
        let token: ProgressToken
    }

    public func handle(handler: any MessageHandler, id: RequestID) async -> (any ResponseType)? {
        fatalError("WindowWorkDoneProgressCreate not implemented")
    }
}

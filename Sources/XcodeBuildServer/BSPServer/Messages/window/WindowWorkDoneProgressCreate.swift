//
//  Untitled.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/23.
//

public struct CreateWorkDoneProgressRequest: RequestType {
    struct Params: Codable {
        let token: ProgressToken
    }

    public static let method: String = "window/workDoneProgress/create"

    public func handle(handler: any MessageHandler, id: RequestID) async -> (any ResponseType)? {
        fatalError("WindowWorkDoneProgressCreate not implemented")
    }
}

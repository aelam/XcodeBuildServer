//
//  processRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/22.
//

struct ProcessRequest: RequestType, Sendable {
    static var method: String { "process" }
    
    func handle(_ handler: MessageHandler, id: RequestID) async -> ResponseType? {
        fatalError()
    }
}

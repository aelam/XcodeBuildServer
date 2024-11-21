//
//  ProcessRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

struct ProcessRequest: RequestType, Sendable {
    static var method: String { "process" }

    func handle(_: MessageHandler, id _: RequestID) async -> ResponseType? {
        fatalError()
    }
}

//
//  BuiltTargetSourcesRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

struct BuiltTargetSourcesRequest: RequestType, Sendable {
    struct Params {
        let language: LanguageId?
        let isHeader: Bool?
    }

    static var method: String { "buildTarget/sources" }

    func handle(_: any MessageHandler, id _: RequestID) async -> (any ResponseType)? {
        nil
    }
}

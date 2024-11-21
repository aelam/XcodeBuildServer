//
//  BuiltTargetSourcesRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/22.
//

import Foundation

typealias LanguageId = String

struct BuiltTargetSourcesRequest: RequestType, Sendable {
    struct Params {
        let language: LanguageId?
        let isHeader: Bool?
    }
    
    static var method: String { "buildTarget/sources" }
    
    func handle(_ handler: MessageHandler, id: RequestID) async throws -> ResponseType {
        let sources = try handler.buildServerContext.builtTargetSources()
        return BuiltTargetSourcesResponse(sources: sources)
    }
}

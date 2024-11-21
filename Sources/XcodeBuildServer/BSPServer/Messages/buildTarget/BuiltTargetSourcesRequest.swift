//
//  BuiltTargetSourcesRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/22.
//

import Foundation

struct BuiltTargetSourcesRequest: RequestType, Sendable {
    struct Params {
        let language: LanguageId?
        let isHeader: Bool?
    }
    
    static var method: String { "buildTarget/sources" }
    
    func handle(_ handler: any MessageHandler, id: RequestID) async -> (any ResponseType)? {
        nil
    }    
}

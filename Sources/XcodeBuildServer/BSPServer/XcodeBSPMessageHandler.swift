//
//  DefaultMessageHandler.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

import Foundation

public final class XcodeBSPMessageHandler: MessageHandler, Sendable {
    let buildServerContext = BuildServerContext()
    
    public init() {

    }
    
    public func initialize(rootURL: URL) async throws {
        try await buildServerContext.loadProject(rootURL: rootURL)
    }
}

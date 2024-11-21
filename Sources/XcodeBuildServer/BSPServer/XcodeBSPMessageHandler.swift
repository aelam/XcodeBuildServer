//
//  XcodeBSPMessageHandler.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public final class XcodeBSPMessageHandler: MessageHandler, Sendable {
    let buildServerContext = BuildServerContext()

    public init() {}

    public func initialize(rootURL: URL) async throws {
        try await buildServerContext.loadProject(rootURL: rootURL)
    }
}

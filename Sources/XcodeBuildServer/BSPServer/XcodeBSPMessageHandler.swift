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

    func getBuildSettings() async -> [BuildSettings]? {
        await buildServerContext.buildSettings
    }

    func getIndexStoreURL() async -> URL? {
        await buildServerContext.indexStoreURL
    }

    func getIndexDatabaseURL() async -> URL? {
        await buildServerContext.indexDatabaseURL
    }

    func getCompileArguments(fileURI: String) async -> [String] {
        await buildServerContext.getCompileArguments(fileURI: fileURI)
    }

    func getRootURL() async -> URL? {
        await buildServerContext.rootURL
    }
}

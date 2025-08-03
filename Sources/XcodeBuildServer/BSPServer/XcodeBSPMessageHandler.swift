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
        return await buildServerContext.buildSettings
    }

    func getIndexStoreURL() async -> URL? {
        return await buildServerContext.indexStoreURL
    }

    func getIndexDatabaseURL() async -> URL? {
        return await buildServerContext.indexDatabaseURL
    }

    func getCompileArguments(fileURI: String) async -> [String] {
        return await buildServerContext.getCompileArguments(fileURI: fileURI)
    }

    func getRootURL() async -> URL? {
        return await buildServerContext.rootURL
    }
}

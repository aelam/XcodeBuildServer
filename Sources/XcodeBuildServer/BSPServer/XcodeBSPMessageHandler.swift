//
//  XcodeBSPMessageHandler.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCServer
import XcodeProjectManagement

/// Languages supported by XcodeBuildServer for Xcode projects
public let xcodeBuildServerSupportedLanguages: Set<Language> = [.swift, .objective_c, .objective_cpp, .c, .cpp]

public final class XcodeBSPMessageHandler: ContextualMessageHandler, Sendable {
    public typealias Context = BuildServerContext
    let buildServerContext = BuildServerContext()

    /// Languages supported by XcodeBuildServer for Xcode projects
    public let supportedLanguages: Set<Language> = xcodeBuildServerSupportedLanguages

    public init() {}

    public func initialize(rootURL: URL) async throws {
        try await buildServerContext.loadProject(rootURL: rootURL)
    }

    public func withContext<T>(_ operation: @escaping @Sendable (BuildServerContext) async throws -> T) async rethrows
        -> T {
        try await operation(buildServerContext)
    }

    func getBuildSettings() async -> [XcodeBuildSettings]? {
        guard await buildServerContext.isLoaded else {
            return nil
        }
        return await buildServerContext.settingsManager?.buildSettings
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

    /// Get the languages supported by this XcodeBuildServer instance
    public func getSupportedLanguages() -> Set<Language> {
        supportedLanguages
    }
}

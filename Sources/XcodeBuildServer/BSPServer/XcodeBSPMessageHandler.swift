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

    public func withContext<T>(_ operation: @escaping @Sendable (BuildServerContext) async throws -> T) async rethrows
        -> T {
        try await operation(buildServerContext)
    }
}

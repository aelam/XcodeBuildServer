//
//  ProjectManagerProvider.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

public enum ProjectManagerProviderError: Error, Sendable {
    case notImplemented
}

public enum Platform: String, Codable, CaseIterable, Sendable {
    case macOS
    case linux
    case windows
    case iOS
    case watchOS
    case tvOS
    case visionOS
}

public protocol ProjectManagerProvider: Sendable {
    var name: String { get }

    // var supportedPlatforms: [Platform] { get }

    func canHandle(projectURL: URL) async -> Bool

    func createProjectManager(rootURL: URL, config: ProjectConfiguration?) async throws -> any ProjectManager
}

public struct ProjectConfiguration: Sendable {
    public let customSettings: [String: String]
    public let workingDirectory: URL?

    public init(customSettings: [String: String] = [:], workingDirectory: URL? = nil) {
        self.customSettings = customSettings
        self.workingDirectory = workingDirectory
    }
}

public actor ProjectManagerFactory {
    private var providers: [any ProjectManagerProvider] = []

    public init() {}

    public func registerProvider(_ provider: any ProjectManagerProvider) {
        providers.append(provider)
    }

    public func getRegisteredProviders() -> [any ProjectManagerProvider] {
        providers
    }

    public func createProjectManager(
        rootURL: URL,
        config: ProjectConfiguration? = nil
    ) async throws -> any ProjectManager {
        try await Task.detached {
            let providers = await self.providers
            logger.debug("Creating project manager for \(rootURL.path)")
            // 检查所有Provider，找到第一个能处理此项目的
            for provider in providers where await provider.canHandle(projectURL: rootURL) {
                return try await provider.createProjectManager(rootURL: rootURL, config: config)
            }

            throw ProjectManagerFactoryError.noSuitableProvider(
                "No provider found for project at: \(rootURL.path)"
            )
        }.value
    }
}

/// 项目管理器工厂错误
public enum ProjectManagerFactoryError: Error, LocalizedError {
    case noSuitableProvider(String)
    case providerCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .noSuitableProvider(message):
            "No suitable provider: \(message)"
        case let .providerCreationFailed(message):
            "Provider creation failed: \(message)"
        }
    }
}

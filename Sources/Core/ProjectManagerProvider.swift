//
//  ProjectManagerProvider.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// 项目管理器提供者协议
/// 用于创建特定类型的项目管理器
public protocol ProjectManagerProvider: Sendable {
    /// 提供者名称
    var name: String { get }

    /// 支持的项目类型
    var supportedProjectTypes: [BSPProjectType] { get }

    /// 支持的平台
    var supportedPlatforms: [Platform] { get }

    /// 检查是否可以处理指定的项目
    func canHandle(projectURL: URL) async -> Bool

    /// 创建项目管理器
    func createProjectManager(rootURL: URL, config: ProjectConfiguration?) async throws -> any ProjectManager
}

/// 项目配置
public struct ProjectConfiguration: Sendable {
    public let customSettings: [String: String]
    public let workingDirectory: URL?

    public init(customSettings: [String: String] = [:], workingDirectory: URL? = nil) {
        self.customSettings = customSettings
        self.workingDirectory = workingDirectory
    }
}

/// 项目管理器工厂
/// 管理所有可用的Provider并选择合适的Provider
public actor ProjectManagerFactory {
    private var providers: [any ProjectManagerProvider] = []

    public init() {}

    /// 注册Provider
    public func registerProvider(_ provider: any ProjectManagerProvider) {
        providers.append(provider)
    }

    /// 获取所有已注册的Provider
    public func getRegisteredProviders() -> [any ProjectManagerProvider] {
        providers
    }

    /// 为指定项目创建合适的ProjectManager
    public func createProjectManager(
        rootURL: URL,
        config: ProjectConfiguration? = nil
    ) async throws -> any ProjectManager {
        // 检查所有Provider，找到第一个能处理此项目的
        for provider in providers {
            if await provider.canHandle(projectURL: rootURL) {
                return try await provider.createProjectManager(rootURL: rootURL, config: config)
            }
        }

        throw ProjectManagerFactoryError.noSuitableProvider(
            "No provider found for project at: \(rootURL.path)"
        )
    }

    /// 检测项目类型
    public func detectProjectType(rootURL: URL) async -> BSPProjectType {
        for provider in providers {
            if await provider.canHandle(projectURL: rootURL) {
                return provider.supportedProjectTypes.first ?? .unknown
            }
        }
        return .unknown
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

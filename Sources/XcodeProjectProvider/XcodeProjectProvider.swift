//
//  XcodeProjectProvider.swift
//  XcodeProjectProvider Module
//
//  Copyright © 2024 Wang Lun.
//

import Core
import Foundation

#if os(macOS)
import XcodeProj

/// Xcode 项目提供者 - 完整实现
public struct XcodeProjectProvider: ProjectManagerProvider {
    public let name = "Xcode Project Provider"
    public let supportedPlatforms: [Platform] = [.macOS]

    public init() {}

    public func canHandle(projectURL: URL) async -> Bool {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: projectURL.path)
            return contents.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
        } catch {
            return false
        }
    }

    public func createProjectManager(
        rootURL: URL,
        config: ProjectConfiguration?
    ) async throws -> any ProjectManager {
        // TODO: 实现完整的XcodeProjectManager创建逻辑
        // 现在有XcodeProj依赖，可以实现完整功能
        throw XcodeProjectProviderError.notImplemented("XcodeProjectManager implementation needed")
    }
}

#else
// 空实现 - 用于非macOS平台
/// Xcode 项目提供者 - 空实现
public struct XcodeProjectProvider: ProjectManagerProvider {
    public let name = "Xcode Project Provider (Disabled)"
    public let supportedProjectTypes: [BSPProjectType] = []
    public let supportedPlatforms: [Platform] = []

    public init() {}

    public func canHandle(projectURL: URL) async -> Bool {
        false
    }

    public func createProjectManager(
        rootURL: URL,
        config: ProjectConfiguration?
    ) async throws -> any ProjectManager {
        throw XcodeProjectProviderError.notAvailable("XcodeProjectProvider not available on this platform")
    }
}
#endif

// MARK: - 错误类型

public enum XcodeProjectProviderError: Error, LocalizedError {
    case notAvailable(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case let .notAvailable(message):
            "Xcode provider not available: \(message)"
        case let .notImplemented(message):
            "Xcode provider not implemented: \(message)"
        }
    }
}

//
//  SwiftPMProjectProvider.swift
//  SwiftPMProjectProvider Module
//
//  Copyright © 2024 Wang Lun.
//

import Core
import Foundation

/// SwiftPM 项目提供者
/// 支持所有平台的SwiftPM项目管理
public struct SwiftPMProjectProvider: ProjectManagerProvider {
    public let name = "SwiftPM Project Provider"

    public let supportedProjectTypes: [BSPProjectType] = [.swiftpm]

    public let supportedPlatforms: [Platform] = [.macOS, .linux, .windows]

    public init() {}

    /// 检查是否可以处理指定的项目
    public func canHandle(projectURL: URL) async -> Bool {
        let packageSwiftPath = projectURL.appendingPathComponent("Package.swift")
        return FileManager.default.fileExists(atPath: packageSwiftPath.path)
    }

    /// 创建SwiftPM项目管理器
    public func createProjectManager(
        rootURL: URL,
        config: ProjectConfiguration?
    ) async throws -> any ProjectManager {
        SwiftPMProjectManager(rootURL: rootURL, config: config)
    }
}

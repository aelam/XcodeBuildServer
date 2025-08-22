//
//  SwiftPMProjectManagerProvider.swift
//  SwiftPMProjectManagerProvider Module
//
//  Copyright © 2024 Wang Lun.
//

import Core
import Foundation

public struct SwiftPMProjectManagerProvider: ProjectManagerProvider {
    enum SwiftPMProjectManagerProviderError: Error {
        case notImplemented
    }

    public let name = "SwiftPMProjectManagerProvider"

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
        throw SwiftPMProjectManagerProviderError.notImplemented
    }
}

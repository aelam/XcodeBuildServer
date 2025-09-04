//
//  SwiftPMProjectManagerProvider.swift
//  SwiftPMProjectManagerProvider Module
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

public struct SwiftPMProjectManagerProvider: ProjectManagerProvider {
    enum SwiftPMProjectManagerProviderError: Error {
        case notImplemented
    }

    public let name = "SwiftPMProjectManagerProvider"

    public init() {}

    public func canHandle(projectURL: URL) async -> Bool {
        false
        // let packageSwiftPath = projectURL.appendingPathComponent("Package.swift")
        // return FileManager.default.fileExists(atPath: packageSwiftPath.path)
    }

    public func createProjectManager(
        rootURL: URL,
        config: ProjectConfiguration?
    ) async throws -> any ProjectManager {
        throw SwiftPMProjectManagerProviderError.notImplemented
    }
}

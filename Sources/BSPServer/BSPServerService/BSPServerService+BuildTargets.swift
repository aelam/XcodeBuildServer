//
//  BSPServerService+BuildTargets.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection
import Logger
import os

extension BSPServerService {
    func getWorkingDirectory() async throws -> String? {
        await projectManager?.rootURL.path
    }

    func createBuildTargets() async throws -> [BSPBuildTarget] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project manager not initialized")
        }

        let targetList = await projectManager.getTargetList(
            resolveSourceFiles: false,
            resolveDependencies: false
        )

        return targetList.map { BSPBuildTarget(projectTarget: $0) }.compactMap(\.self)
    }

    /// 为索引构建目标（BSP 协议适配）
    func buildTargetForIndex(targets: [BSPBuildTargetIdentifier]) async throws {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project not initialized")
        }

        await projectManager.buildIndex(for: targets)
    }

    func compileTargets(_ targetIdentifiers: [BSPBuildTargetIdentifier]) async throws -> StatusCode {
        guard let projectManager else {
            logger.error("Project not initialized")
            return .error
        }

        return try await projectManager.startBuild(targetIdentifiers: targetIdentifiers)
    }
}

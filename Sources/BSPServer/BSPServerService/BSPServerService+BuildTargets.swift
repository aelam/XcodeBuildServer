//
//  BSPServerService+BuildTargets.swift
//
//  Copyright © 2024 Wang Lun.
//

import Core
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
    func buildTargetForIndex(targets: [BuildTargetIdentifier]) async throws {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project not initialized")
        }

        let targetIdentifiers = targets.map(\.uri.stringValue)

        await projectManager.startBuild(targets: targetIdentifiers)
    }
}

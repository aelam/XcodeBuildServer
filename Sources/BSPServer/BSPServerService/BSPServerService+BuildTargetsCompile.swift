import BuildServerProtocol
import Foundation
import JSONRPCConnection
import Logger
import os

extension BSPServerService {
    func compileTargets(
        _ targetIdentifiers: [BSPBuildTargetIdentifier],
        originId: String? = nil
    ) async throws -> StatusCode {
        guard let projectManager else {
            logger.error("Project not initialized")
            return .error
        }

        // 使用BSPTaskManager来处理任务管理和进度报告
        let taskManager = getTaskManager()

        // 使用ParsedBuild方法来获得真实的构建进度
        return try await taskManager.executeBuildWithProgress(
            using: projectManager,
            targets: targetIdentifiers,
            originId: originId
        )
    }
}

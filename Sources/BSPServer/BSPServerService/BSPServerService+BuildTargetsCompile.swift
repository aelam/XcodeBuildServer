import BuildServerProtocol
import Foundation
import JSONRPCConnection
import Logger

extension BSPServerService {
    func compileTargets(
        _ targetIdentifiers: [BSPBuildTargetIdentifier],
        originId: String? = nil,
        arguments: [String]? = nil
    ) async throws -> StatusCode {
        guard let projectManager else {
            logger.error("Project not initialized")
            return .error
        }

        // 获取taskManager和projectManager的引用，然后在非隔离上下文中执行
        let taskManager = getTaskManager()

        // 将长时间运行的任务移到非隔离上下文
        return try await Task.detached {
            try await taskManager.executeCompileWithProgress(
                using: projectManager,
                targets: targetIdentifiers,
                originId: originId,
                arguments: arguments
            )
        }.value
    }
}

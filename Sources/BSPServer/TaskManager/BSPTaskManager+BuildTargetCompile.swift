//
//  BSPTaskManager+BuildTargetCompile.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

public extension BSPTaskManager {
    /// Execute build with progress parsed from xcodebuild output
    /// 这是最理想的方案 - 通过解析构建工具的输出来获得真实进度
    func executeBuildWithProgress(
        using projectManager: any ProjectManager,
        targets: [BSPBuildTargetIdentifier],
        originId: String? = nil
    ) async throws -> StatusCode {
        let targetNames = targets.map(\.uri.stringValue).joined(separator: ", ")
        let task = try await startTask(
            originId: originId,
            message: "Building targets: \(targetNames)",
            targets: targets
        )

        do {
            let taskId = task.taskId

            let status = try await projectManager.startBuild(
                targetIdentifiers: targets
            ) { message, progress in
                Task {
                    do {
                        let clampedProgress = min(max(progress ?? 0.0, 0.0), 1.0)
                        try await self.sendTaskProgressNotification(
                            taskId: taskId,
                            progress: clampedProgress,
                            message: message
                        )
                    } catch {
                        // 忽略进度通知错误，避免中断构建
                    }
                }
            }

            try await finishTask(
                taskId: task.taskId,
                status: task.status ?? .error,
                message: task.currentMessage ?? "Build finished"
            )

            return status
        } catch {
            // 通过 TaskManager 正确处理任务失败
            try await finishTask(
                taskId: task.taskId,
                status: .error,
                message: "Build failed: \(error.localizedDescription)"
            )
            throw error
        }
    }
}

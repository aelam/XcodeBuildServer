//
//  BSPTaskManager+BuildTargetCompile.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

public extension BSPTaskManager {
    /// Execute build with progress parsed from xcodebuild output
    /// 避免在 Actor 上下文中长时间等待，使用 Task.detached 在独立上下文中执行构建
    func executeCompileWithProgress(
        using projectManager: any ProjectManager,
        targets: [BSPBuildTargetIdentifier],
        originId: String? = nil,
        arguments: [String]? = nil
    ) async throws -> StatusCode {
        let targetNames = targets.map(\.uri.stringValue).joined(separator: ", ")

        let task = try await startTask(
            originId: originId,
            message: "compile targets: \(targetNames)"
        )

        let taskId = task.taskId

        do {
            let status = try await projectManager.startBuild(
                targetIdentifiers: targets,
                arguments: arguments
            )
            try await finishTask(
                taskId: taskId,
                status: status,
                message: status == .ok ? "Build completed successfully" : "Build completed with errors"
            )

            return status
        } catch {
            try await finishTask(
                taskId: taskId,
                status: .error,
                message: "Build failed: \(error.localizedDescription)"
            )
            throw error
        }
    }
}

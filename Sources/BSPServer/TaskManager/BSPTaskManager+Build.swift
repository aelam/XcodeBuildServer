//
//  BSPTaskManager+Build.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

/// Extension to BSPTaskManager for project-based build execution
public extension BSPTaskManager {
    /// Execute a build command using ProjectManager with task tracking
    /// 调用链: projectManagerProvider → projectManager → startBuild → xcodebuild/swift build
    func executeBuild(
        using projectManager: any ProjectManager,
        targets: [BSPBuildTargetIdentifier],
        originId: String? = nil
    ) async throws -> StatusCode {
        let targetNames = targets.map(\.uri.stringValue).joined(separator: ", ")

        // 创建任务但不在 actor 内部处理进度更新
        let task = try await startTask(
            originId: originId,
            message: "Building targets: \(targetNames)",
            targets: targets
        )

        // 在 Task 中执行构建和进度更新，避免 actor 死锁
        return try await withThrowingTaskGroup(of: StatusCode.self) { group in
            // 启动构建任务
            group.addTask {
                do {
                    let status = try await projectManager.startBuild(targetIdentifiers: targets)
                    return status
                } catch {
                    throw error
                }
            }

            // 启动进度更新任务
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    try await task.updateProgress(progress: 0.1, message: "Starting build...")

                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    try await task.updateProgress(progress: 0.2, message: "Preparing build...")

                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    try await task.updateProgress(progress: 0.3, message: "Compiling...")

                    // 继续定期更新进度
                    for i in 1 ... 6 {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                        let progress = 0.3 + (0.4 * Double(i) / 6.0)
                        try await task.updateProgress(
                            progress: progress,
                            message: "Building... (\(Int(progress * 100))%)"
                        )
                    }

                    // 这个任务永远不会正常完成，会被构建完成时取消
                    return .ok
                } catch {
                    return .error
                }
            }

            // 等待构建完成
            for try await result in group {
                // 取消所有其他任务
                group.cancelAll()

                // 发送最终进度和完成通知
                let finalProgress = 1.0
                let progressMessage = result == .ok ? "Build completed successfully" : "Build completed with errors"
                try await task.updateProgress(progress: finalProgress, message: progressMessage)

                let message = result == .ok ? "Build completed successfully" : "Build failed"
                try await task.finish(status: result, message: message)

                return result
            }

            // 不应该到达这里
            try await task.fail(message: "Build task completed unexpectedly")
            return .error
        }
    }
}

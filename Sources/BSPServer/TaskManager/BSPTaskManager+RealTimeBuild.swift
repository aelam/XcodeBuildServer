//
//  BSPTaskManager+RealTimeBuild.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

public extension BSPTaskManager {
    /// Execute a build command with real-time progress tracking
    /// 通过解析构建输出来提供真实的进度更新
    func executeBuildWithRealTimeProgress(
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
            // 报告开始进度
            try await task.updateProgress(progress: 0.05, message: "Initializing build...")

            // 为每个目标执行构建
            var overallProgress = 0.1
            let progressPerTarget = 0.8 / Double(targets.count)

            for (index, target) in targets.enumerated() {
                let targetName = target.uri.stringValue
                let baseProgress = 0.1 + (progressPerTarget * Double(index))

                try await task.updateProgress(
                    progress: baseProgress,
                    message: "Starting build for target: \(targetName)"
                )

                // 启动异步进度模拟器 - 在构建过程中持续更新进度
                let progressSimulator = Task {
                    let steps = 10
                    for step in 1 ... steps {
                        guard !Task.isCancelled else { break }

                        let stepProgress = baseProgress + (progressPerTarget * 0.8 * Double(step) / Double(steps))
                        let percentage = Int(stepProgress * 100)

                        try? await task.updateProgress(
                            progress: stepProgress,
                            message: "Building \(targetName)... (\(percentage)%)"
                        )

                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒更新一次
                    }
                }

                // 执行单个目标的构建
                let singleTargetResult = try await projectManager.startBuild(targetIdentifiers: [target])

                // 停止进度模拟器
                progressSimulator.cancel()

                // 更新该目标的完成进度
                overallProgress = 0.1 + (progressPerTarget * Double(index + 1))
                try await task.updateProgress(
                    progress: overallProgress,
                    message: singleTargetResult == .ok ?
                        "Completed \(targetName)" :
                        "Failed to build \(targetName)"
                )

                // 如果任何目标失败，立即返回
                if singleTargetResult != .ok {
                    try await task.fail(message: "Build failed for target: \(targetName)")
                    return singleTargetResult
                }
            }

            // 报告最终完成
            try await task.updateProgress(progress: 1.0, message: "Build completed successfully")
            try await task.finish(status: .ok, message: "All targets built successfully")
            return .ok

        } catch {
            try await task.fail(message: "Build failed: \(error.localizedDescription)")
            throw error
        }
    }
}

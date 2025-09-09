//
//  BSPTaskManager+ParsedBuild.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

extension BSPTaskManager {
    /// Execute build with progress parsed from xcodebuild output
    /// 这是最理想的方案 - 通过解析构建工具的输出来获得真实进度
    public func executeBuildWithParsedProgress(
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

        // 这里需要修改 ProjectManager 来支持进度回调
        // 或者直接调用底层的构建工具并解析输出

        do {
            try await task.updateProgress(progress: 0.1, message: "Starting build...")

            // TODO: 实现真实的进度解析
            // 这需要：
            // 1. 修改 ProjectManager.startBuild 支持进度回调
            // 2. 或者在这里直接调用 xcodebuild/swift build 并解析输出
            // 3. 解析构建输出中的文件编译进度信息

            let status = try await projectManager.startBuild(targetIdentifiers: targets)

            try await task.updateProgress(progress: 1.0, message: "Build completed")
            try await task.finish(status: status, message: "Build finished")
            return status

        } catch {
            try await task.fail(message: "Build failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// 解析 xcodebuild 输出来提取进度信息
    private func parseXcodeBuildProgress(_ output: String) -> (progress: Double, message: String)? {
        // 解析类似这样的输出：
        // "Building target 'MyApp' (1 of 3)"
        // "Compiling MyFile.swift (5 of 20)"
        // "Linking MyApp"

        if output.contains("Building target") {
            // 提取目标构建进度
            return (0.3, "Building target...")
        } else if output.contains("Compiling") {
            // 提取文件编译进度
            if output.range(of: #"\((\d+) of (\d+)\)"#, options: .regularExpression) != nil {
                // TODO: 解析 "(5 of 20)" 格式并返回相应的进度百分比
            }
            return (0.6, "Compiling files...")
        } else if output.contains("Linking") {
            return (0.9, "Linking...")
        }

        return nil
    }
}

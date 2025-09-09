import BuildServerProtocol
import Foundation
import Logger
import Support
import XcodeProjectManagement

extension XcodeProjectManager: @preconcurrency ProjectManager {
    public func getProjectState() async -> BuildServerProtocol.ProjectState {
        .init()
    }

    public func addStateObserver(_ observer: any BuildServerProtocol.ProjectStateObserver) async {}

    public func removeStateObserver(_ observer: any BuildServerProtocol.ProjectStateObserver) async {}

    public var projectType: String {
        "xcodeproj"
    }

    public func updateBuildGraph() async {}

    public func buildIndex(for targets: [BSPBuildTargetIdentifier]) async {
        // TODO: await startBuild(targetIdentifiers: targets)
    }

    public func startBuild(
        targetIdentifiers: [BSPBuildTargetIdentifier],
        progress: (@Sendable (String, Double?) -> Void)?
    ) async throws -> StatusCode {
        var results: [XcodeBuildResult] = []
        let totalTargets = targetIdentifiers.count

        for (index, identifier) in targetIdentifiers.enumerated() {
            let xcodeTargetIdentifier = XcodeTargetIdentifier(rawValue: identifier.uri.stringValue)

            // 报告开始构建目标的进度
            let targetProgress = Double(index) / Double(totalTargets)
            progress?("Building target: \(xcodeTargetIdentifier.targetName)", targetProgress)

            // 创建进度回调包装器来将ProcessProgressEvent转换为简单的进度
            let processProgress: ProcessProgress = { event in
                switch event {
                case .outputData:
                    // 可以在这里解析输出来提取更具体的进度信息
                    break
                case .errorData:
                    // 处理错误输出
                    break
                case let .progressUpdate(progressDouble, message):
                    // 计算总体进度 = 目标进度 + 当前目标内部进度
                    let overallProgress = targetProgress + (progressDouble / Double(totalTargets))
                    progress?(message ?? "Building...", overallProgress)
                }
            }

            let xcodeBuildResult = try await compileTarget(
                targetIdentifier: xcodeTargetIdentifier,
                progress: processProgress
            )
            results.append(xcodeBuildResult)

            // 报告目标完成进度
            let completedProgress = Double(index + 1) / Double(totalTargets)
            progress?("Completed target: \(xcodeTargetIdentifier.targetName)", completedProgress)
        }

        for result in results where result.exitCode != 0 {
            logger.error("Build failed with exit code \(result.exitCode)")
            if let errorOutput = result.error, !errorOutput.isEmpty {
                logger.error("Build failed: \(errorOutput)")
            }
            progress?("Build failed", 1.0)
            return .error
        }

        progress?("Build completed successfully", 1.0)
        return .ok
    }

    public var projectInfo: ProjectInfo? {
        xcodeProjectBaseInfo?.asProjectInfo()
    }

    public func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget] {
        projectInfo?.targets ?? []
    }

    public func getSourceFileList(targetIdentifiers: [BSPBuildTargetIdentifier]) async throws
        -> [BuildServerProtocol.SourcesItem] {
        let xcodeTargetIdentifiers = targetIdentifiers.map { identifier in
            XcodeTargetIdentifier(rawValue: identifier.uri.stringValue)
        }
        let xcodeSourceItems = getSourcesItems(targetIdentifiers: xcodeTargetIdentifiers)
        return try xcodeSourceItems.compactMap {
            try $0.asBSPSourcesItems()
        }
    }

    public func getCompileArguments(targetIdentifier: String, sourceFileURL: URL) async throws -> [String] {
        let xcodeTargetIdentifier = XcodeTargetIdentifier(rawValue: targetIdentifier)
        return try await getCompileArguments(targetIdentifier: xcodeTargetIdentifier, sourceFileURL: sourceFileURL)
    }
}

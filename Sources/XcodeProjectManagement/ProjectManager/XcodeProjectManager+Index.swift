import Foundation

public enum BuildError: Error, Sendable {
    case buildFailed(exitCode: Int32, output: String)
}

public extension XcodeProjectManager {
    func buildProject(
        projectInfo: XcodeProjectInfo,
    ) async throws -> XcodeBuildResult {
        let importantScheme = projectInfo.baseProjectInfo.importantScheme
        let targetName = importantScheme.name

        // 使用状态管理开始构建
        await startBuild(target: targetName)

        // Notify build started (保持向后兼容)
        // await notifyObservers(ProjectStatusEvent.buildStarted(target: targetName))
        let startTime = Date()

        // Build Target
        let result: XcodeBuildResult = switch projectInfo.baseProjectInfo.projectLocation {
        case let .explicitWorkspace(workspaceURL):
            try await buildWorkspace(
                workspaceURL: workspaceURL,
                scheme: importantScheme,
                configuration: projectInfo.baseProjectInfo.configuration
            )
        case let .implicitWorkspace(_, workspaceURL):
            try await buildWorkspace(
                workspaceURL: workspaceURL,
                scheme: importantScheme,
                configuration: projectInfo.baseProjectInfo.configuration
            )
        case let .standaloneProject(projectURL):
            try await buildProject(
                projectURL: projectURL,
                scheme: importantScheme,
                configuration: projectInfo.baseProjectInfo.configuration,
                derivedDataPath: projectInfo.baseProjectInfo.xcodeProjectBuildSettings.derivedDataPath,
                rootURL: projectInfo.baseProjectInfo.rootURL
            )
        }

        // 使用状态管理更新构建结果
        let duration = Date().timeIntervalSince(startTime)
        let success = result.exitCode == 0
        if success {
            await completeBuild(target: targetName, duration: duration, success: true)
        } else {
            let error = BuildError.buildFailed(exitCode: result.exitCode, output: result.output)
            await failBuild(target: targetName, error: error)
        }

        return result
    }

    private func buildWorkspace(
        workspaceURL: URL,
        scheme: XcodeScheme,
        configuration: String
    ) async throws -> XcodeBuildResult {
        let options = XcodeBuildOptions(
            command: .build(
                action: .build,
                sdk: .iOSSimulator,
                destination: nil,
                configuration: configuration,
                derivedDataPath: nil,
                resultBundlePath: nil
            ),
            flags: XcodeBuildFlags(),
            customFlags: [
            ]
        )

        let commandBuilder = XcodeBuildCommandBuilder()
        let command = commandBuilder.buildCommand(
            project: .workspace(
                workspaceURL: workspaceURL,
                scheme: scheme.name
            ),
            options: options
        )

        let result = try await toolchain.executeXcodeBuild(
            arguments: command,
            workingDirectory: workspaceURL
        )
        return result
    }

    private func buildProject(
        projectURL: URL,
        scheme: XcodeScheme,
        configuration: String,
        derivedDataPath: URL,
        rootURL: URL
    ) async throws -> XcodeBuildResult {
        let options = XcodeBuildOptions(
            command: .build(
                action: .build,
                sdk: .iOSSimulator,
                destination: nil,
                configuration: configuration,
                derivedDataPath: nil,
                resultBundlePath: nil
            ),
            flags: XcodeBuildFlags(),
            customFlags: [
            ]
        )

        let commandBuilder = XcodeBuildCommandBuilder()
        let command = commandBuilder.buildCommand(
            project: .project(
                projectURL: projectURL,
                buildMode: .scheme(scheme.name)
            ),
            options: options
        )

        let result = try await toolchain.executeXcodeBuild(
            arguments: command,
            workingDirectory: rootURL
        )
        return result
    }
}

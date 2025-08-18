import Foundation

public extension XcodeProjectManager {
    func buildTargetForIndex(
        _ target: String,
        projectInfo: XcodeProjectInfo,
    ) async throws -> XcodeBuildResult {
        let targetIdentifier = TargetIdentifier(rawValue: target)
        let projectPath = targetIdentifier.projectFilePath
        let targetName = targetIdentifier.targetName
        let importantScheme = projectInfo.importantScheme

        // Build Target
        switch projectInfo.projectLocation {
        case let .explicitWorkspace(workspaceURL):
            return try await buildWorkspace(
                workspaceURL: workspaceURL,
                scheme: importantScheme,
                configuration: projectInfo.primaryBuildSettings.configuration
            )
        case let .implicitWorkspace(projectURL, workspaceURL):
            return try await buildWorkspace(
                workspaceURL: workspaceURL,
                scheme: importantScheme,
                configuration: projectInfo.primaryBuildSettings.configuration
            )
        case let .standaloneProject(projectURL):
            return try await buildProject(
                projectURL: projectURL,
                scheme: importantScheme,
                configuration: projectInfo.primaryBuildSettings.configuration,
                derivedDataPath: projectInfo.primaryBuildSettings.derivedDataPath,
                rootURL: projectInfo.rootURL
            )
        }
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

import Foundation

public enum BuildError: Error, Sendable {
    case buildFailed(exitCode: Int32, output: String)
}

public extension XcodeProjectManager {
    func buildProject(
        projectInfo: XcodeProjectInfo,
    ) async throws -> XcodeBuildResult {
        XcodeBuildResult(output: "String", error: nil, exitCode: 0)
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

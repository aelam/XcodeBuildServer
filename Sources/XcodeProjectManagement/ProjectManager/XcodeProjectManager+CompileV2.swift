import Foundation
import Support

public enum BuildError: Error, Sendable {
    case buildFailed(exitCode: Int32, output: String)
}

public extension XcodeProjectManager {
    func compileTarget(
        targetIdentifier: XcodeTargetIdentifier,
        configuration: String = "Debug",
        progress: ProcessProgress? = nil
    ) async throws -> XcodeBuildResult {
        guard let xcodeProjectBaseInfo else {
            return XcodeBuildResult(output: "", error: "No Xcode project found", exitCode: 1)
        }

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
            customFlags: []
        )

        let projectBuildConfiguration: XcodeProjectConfiguration = switch xcodeProjectBaseInfo.projectLocation {
        case let .explicitWorkspace(url):
            .workspace(
                workspaceURL: url,
                scheme: targetIdentifier.targetName
            )
        case let .implicitWorkspace(projectURL: url, workspaceURL: _), let .standaloneProject(url: url):
            .project(
                projectURL: url,
                buildMode: .scheme(targetIdentifier.targetName)
            )
        }

        let commandBuilder = XcodeBuildCommandBuilder()
        let command = commandBuilder.buildCommand(
            project: projectBuildConfiguration,
            options: options
        )

        let result = try await toolchain.executeXcodeBuild(
            arguments: command,
            workingDirectory: rootURL,
            xcodeBuildEnvironments: [:],
            progress: progress
        )
        return result
    }
}

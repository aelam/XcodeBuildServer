import Foundation
import Support

public enum BuildError: Error, Sendable {
    case buildFailed(exitCode: Int32, output: String)
}

public extension XcodeProjectManager {
    func compileTarget(
        targetIdentifier: XcodeTargetIdentifier,
        configuration: String?,
        arguments: [String]? = nil,
        progress: ProcessProgress? = nil
    ) async throws -> XcodeBuildResult {
        guard let xcodeProjectBaseInfo else {
            return XcodeBuildResult(output: "", error: "No Xcode project found", exitCode: 1)
        }

        guard let xcodeTarget = xcodeProjectBaseInfo.xcodeTargets
            .first(where: { $0.targetIdentifier == targetIdentifier }) else {
            return XcodeBuildResult(output: "", error: "No Xcode target found", exitCode: 1)
        }

        let scheme = findOrCreateScheme(for: xcodeTarget, in: xcodeProjectBaseInfo.schemes)

        let buildAction: XcodeBuildCommand.BuildAction = xcodeTarget.xcodeProductType.isTestBundle ?
            .buildForTesting : .build
        let options = XcodeBuildOptions(
            command: .build(
                action: buildAction,
                sdk: nil,
                destination: nil,
                configuration: configuration,
                derivedDataPath: nil,
                resultBundlePath: nil
            ),
            flags: XcodeBuildFlags(),
            customFlags: arguments ?? []
        )

        let projectBuildConfiguration: XcodeProjectConfiguration = switch xcodeProjectBaseInfo.projectLocation {
        case let .explicitWorkspace(url):
            .workspace(
                workspaceURL: url,
                scheme: scheme.name
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
            xcodeBuildEnvironments: [:]
        )
        return result
    }
}

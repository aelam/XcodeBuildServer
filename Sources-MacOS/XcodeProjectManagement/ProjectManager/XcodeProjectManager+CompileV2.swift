import Foundation
import Logger
import Support

public enum BuildError: Error, Sendable {
    case buildFailed(exitCode: Int32, output: String)
}

public extension XcodeProjectManager {
    // MARK: - Generic Xcode Process Execution

    private func executeXcodeProcess(
        command: [String],
        outputHandler: ProcessOutputHandler? = nil
    ) async throws -> XcodeBuildExitCode {
        let process = try await toolchain.createXcodeBuildProcess(
            arguments: command,
            workingDirectory: rootURL,
            xcodeBuildEnvironments: [:]
        )

        process.standardInput = FileHandle.nullDevice
        // Setup pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        process.launch()

        let effectiveHandler = outputHandler ?? DefaultOutputHandler()

        await withTaskGroup(of: Void.self) { group in
            // 启动管道读取任务
            group.addTask {
                await effectiveHandler.handleProcess(
                    output: outputPipe.fileHandleForReading,
                    error: errorPipe.fileHandleForReading
                )
            }

            // 启动进程等待任务
            group.addTask {
                await Task {
                    process.waitUntilExit()
                }.value
            }
        }

        await effectiveHandler.handleCompletion(process.terminationStatus)

        return process.terminationStatus
    }

    // MARK: - Compile Target

    func compileTarget(
        targetIdentifier: XcodeTargetIdentifier,
        configuration: String?,
        arguments: [String]? = nil,
        outputHandler: ProcessOutputHandler? = nil
    ) async throws -> XcodeBuildExitCode {
        guard let xcodeProjectBaseInfo else {
            return 1
        }

        guard let xcodeTarget = xcodeProjectBaseInfo.xcodeTargets
            .first(where: { $0.targetIdentifier == targetIdentifier }) else {
            return 1
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

        return try await executeXcodeProcess(
            command: command,
            outputHandler: outputHandler
        )
    }
}

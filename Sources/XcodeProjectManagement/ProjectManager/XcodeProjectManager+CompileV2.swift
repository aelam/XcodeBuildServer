import Foundation
import Logger
import Support

// MARK: - Process Output Handler Protocol

public protocol ProcessOutputHandler: Sendable {
    func handleProcess(output: FileHandle, error: FileHandle) async
    func handleCompletion(_ exitCode: Int32) async
}

// MARK: - Default Output Handler

private struct DefaultOutputHandler: ProcessOutputHandler {
    func handleProcess(output: FileHandle, error: FileHandle) async {
        // 并发读取两个管道并写入日志，防止管道阻塞
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let outputData = try output.readToEnd() ?? Data()
                    if !outputData.isEmpty, let outputString = String(data: outputData, encoding: .utf8) {
                        logger.info("Build output: \(outputString)")
                    }
                } catch {
                    logger.error("Failed to read output: \(error)")
                }
            }

            group.addTask {
                do {
                    let errorData = try error.readToEnd() ?? Data()
                    if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8) {
                        logger.error("Build error: \(errorString)")
                    }
                } catch {
                    logger.error("Failed to read error: \(error)")
                }
            }
        }
    }

    func handleCompletion(_ exitCode: Int32) async {
        logger.info("Process completed with exit code: \(exitCode)")
    }
}

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

        async let handlerTask: Void = effectiveHandler.handleProcess(
            output: outputPipe.fileHandleForReading,
            error: errorPipe.fileHandleForReading
        )

        await Task {
            process.waitUntilExit()
        }.value

        await handlerTask

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

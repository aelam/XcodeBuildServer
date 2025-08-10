//
//  ProcessExecutor.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

public struct ProcessExecutionResult: Sendable {
    public let output: String
    public let error: String?
    public let exitCode: Int32

    public var isSuccess: Bool {
        exitCode == 0
    }

    public init(output: String, error: String?, exitCode: Int32) {
        self.output = output
        self.error = error
        self.exitCode = exitCode
    }
}

public enum ProcessExecutorError: Error, LocalizedError {
    case executableNotFound(String)
    case processStartFailed(Error)
    case invalidWorkingDirectory(String)
    case timeout(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case let .executableNotFound(path):
            "Executable not found: \(path)"
        case let .processStartFailed(error):
            "Failed to start process: \(error.localizedDescription)"
        case let .invalidWorkingDirectory(path):
            "Invalid working directory: \(path)"
        case let .timeout(duration):
            "Process timed out after \(duration) seconds"
        }
    }
}

public actor ProcessExecutor {
    public init() {}

    public func execute(
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ProcessExecutionResult {
        // Validate executable path
        let executableURL = URL(fileURLWithPath: executable)
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw ProcessExecutorError.executableNotFound(executable)
        }

        // Validate working directory if provided
        if let workingDirectory {
            guard FileManager.default.fileExists(atPath: workingDirectory.path) else {
                throw ProcessExecutorError.invalidWorkingDirectory(workingDirectory.path)
            }
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        // Set working directory if provided
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        // Set environment variables
        var processEnvironment = ProcessInfo.processInfo.environment
        if let environment {
            for (key, value) in environment {
                processEnvironment[key] = value
            }
        }
        process.environment = processEnvironment

        // Create pipes for output and error
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Redirect stdin to /dev/null to prevent hanging on input
        process.standardInput = FileHandle.nullDevice

        // Log the command being executed
        let commandString = "\(executable) \(arguments.joined(separator: " "))"
        logger.debug("ProcessExecutor: Executing command: \(commandString)")
        if let workingDirectory {
            logger.debug("ProcessExecutor: Working directory: \(workingDirectory.path)")
        }

        return try await executeWithModernAPI(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout,
            processEnvironment: processEnvironment
        )
    }
}

// MARK: - Convenience Extensions

public extension ProcessExecutor {
    /// Execute a command with a simple executable path and arguments
    func execute(
        command: String,
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) async throws -> ProcessExecutionResult {
        let components = command.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let executable = components.first else {
            throw ProcessExecutorError.executableNotFound("Empty command")
        }

        let arguments = Array(components.dropFirst())
        return try await execute(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment
        )
    }

    /// Execute xcodebuild with the given arguments
    func executeXcodeBuild(
        arguments: [String],
        workingDirectory: URL? = nil,
        xcodeInstallationPath: URL,
        timeout: TimeInterval? = 60.0 // 增加到60秒超时，因为showBuildSettings可能需要更长时间
    ) async throws -> ProcessExecutionResult {
        // Use the system xcodebuild (which might be managed by xcenv)
        // instead of forcing a specific path
        let xcodebuildPath = "/usr/bin/xcrun"
        let xcrunArgs = ["xcodebuild"] + arguments

        // Set up Xcode environment - but keep it minimal to avoid conflicts
        var environment: [String: String] = [:]

        // Only set DEVELOPER_DIR if it's not already set in the environment
        // This allows xcenv and other tools to work properly
        if ProcessInfo.processInfo.environment["DEVELOPER_DIR"] == nil {
            environment["DEVELOPER_DIR"] = xcodeInstallationPath
                .appendingPathComponent("Contents/Developer").path
        }

        return try await execute(
            executable: xcodebuildPath,
            arguments: xcrunArgs,
            workingDirectory: workingDirectory,
            environment: environment,
            timeout: timeout // 传入timeout参数
        )
    }

    /// Execute xcrun with the given arguments
    func executeXcrun(
        arguments: [String],
        workingDirectory: URL? = nil
    ) async throws -> ProcessExecutionResult {
        try await execute(
            executable: "/usr/bin/xcrun",
            arguments: arguments,
            workingDirectory: workingDirectory
        )
    }

    /// Execute xcode-select with the given arguments
    func executeXcodeSelect(
        arguments: [String] = ["--print-path"],
        workingDirectory: URL? = nil
    ) async throws -> ProcessExecutionResult {
        try await execute(
            executable: "/usr/bin/xcode-select",
            arguments: arguments,
            workingDirectory: workingDirectory
        )
    }

    /// 使用Swift的现代Process API，专门处理大量输出避免缓冲区死锁
    private func executeWithModernAPI(
        executable: String,
        arguments: [String],
        workingDirectory: URL?,
        timeout: TimeInterval?,
        processEnvironment: [String: String]
    ) async throws -> ProcessExecutionResult {
        logger.debug("ProcessExecutor: Executing command: \(executable) \(arguments.joined(separator: " "))")

        return try await withThrowingTaskGroup(of: ProcessExecutionResult?.self) { group in
            // 主执行任务
            group.addTask {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.environment = processEnvironment
                process.standardInput = FileHandle.nullDevice

                if let workingDirectory {
                    process.currentDirectoryURL = workingDirectory
                }

                // 使用现代API
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                try process.run()

                // 关键：使用async/await异步读取，避免缓冲区死锁
                async let outputData = outputPipe.fileHandleForReading.readToEnd()
                async let errorData = errorPipe.fileHandleForReading.readToEnd()

                process.waitUntilExit()

                let output = try await String(data: outputData ?? Data(), encoding: .utf8) ?? ""
                let errorString = try await String(data: errorData ?? Data(), encoding: .utf8) ?? ""
                let error = errorString.isEmpty ? nil : errorString

                logger.debug("ProcessExecutor: Command completed with exit code: \(process.terminationStatus)")
                logger.debug("ProcessExecutor: Output length: \(output.count) characters")

                return ProcessExecutionResult(
                    output: output,
                    error: error,
                    exitCode: process.terminationStatus
                )
            }

            // 超时任务
            if let timeout {
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    logger.warning("ProcessExecutor: Process terminated due to timeout (\(timeout)s)")
                    throw ProcessExecutorError.timeout(timeout)
                }
            }

            // 等待第一个完成的任务
            for try await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }

            let error = NSError(
                domain: "ProcessExecutor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No result returned"]
            )
            throw ProcessExecutorError.processStartFailed(error)
        }
    }
}

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
        logger.debug("ProcessExecutor: \(executable) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        // Set environment
        if let environment {
            var env = ProcessInfo.processInfo.environment
            env.merge(environment) { _, new in new }
            process.environment = env
        }

        // Set working directory
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        // Setup pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Start process
        do {
            try process.run()
        } catch {
            if error.localizedDescription.contains("No such file") {
                throw ProcessExecutorError.executableNotFound(executable)
            }
            throw ProcessExecutorError.processStartFailed(error)
        }

        // Handle timeout if specified
        if let timeout {
            return try await withTimeout(timeout) {
                try await self.readProcessOutput(process: process, outputPipe: outputPipe, errorPipe: errorPipe)
            }
        } else {
            return try await readProcessOutput(process: process, outputPipe: outputPipe, errorPipe: errorPipe)
        }
    }

    private func readProcessOutput(
        process: Process,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) async throws -> ProcessExecutionResult {
        async let outputData = outputPipe.fileHandleForReading.readToEnd()
        async let errorData = errorPipe.fileHandleForReading.readToEnd()

        process.waitUntilExit()

        let output = try await String(data: outputData ?? Data(), encoding: .utf8) ?? ""
        let errorString = try await String(data: errorData ?? Data(), encoding: .utf8) ?? ""

        return ProcessExecutionResult(
            output: output,
            error: errorString.isEmpty ? nil : errorString,
            exitCode: process.terminationStatus
        )
    }

    private func withTimeout<T: Sendable>(
        _ timeout: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ProcessExecutorError.timeout(timeout)
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Xcode related

extension ProcessExecutor {
    /// Execute xcodebuild with the given arguments
    func executeXcodeBuild(
        arguments: [String],
        workingDirectory: URL? = nil,
        xcodeInstallationPath: URL,
        timeout: TimeInterval? = nil
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
            timeout: timeout
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
}

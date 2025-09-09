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

public enum ProcessExecutorError: Error, LocalizedError, Equatable {
    case processStartFailed(String) // System error message
    case invalidWorkingDirectory(String)
    case timeout(TimeInterval)

    public var isTimeout: Bool {
        if case .timeout = self { return true }
        return false
    }
}

public actor ProcessExecutor {
    public init() {}

    public func execute(
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> ProcessExecutionResult {
        logger.debug("\(executable) \(arguments.joined(separator: " "))")

        let process = Process()

        var envrionmentOverrides = ProcessInfo.processInfo.environment
        // Set environment
        if !environment.isEmpty {
            envrionmentOverrides.merge(environment) { _, new in new }
        }
        process.environment = envrionmentOverrides

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

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
            throw ProcessExecutorError.processStartFailed(error.localizedDescription)
        }

        let startTime = Date()
        // Handle timeout if specified
        let result: ProcessExecutionResult = if let timeout {
            try await withTimeout(timeout) {
                try await self.readProcessOutput(process: process, outputPipe: outputPipe, errorPipe: errorPipe)
            }
        } else {
            try await readProcessOutput(process: process, outputPipe: outputPipe, errorPipe: errorPipe)
        }

        logger
            .debug(
                "Command completed \n"
                    + "exit code: \(result.exitCode) , "
                    + "duration: \(Date().timeIntervalSince(startTime)) , "
                    + "length: \(result.output.count)"
            )

        logger
            .debug(
                "Output preview:\n \(String(result.output.prefix(min(2000, result.output.count))))"
            )

        if result.exitCode != 0 {
            logger.error("Command failed with exit code \(result.exitCode)")
            if let error = result.error {
                logger.error("Error output: \(error)")
            }
        }

        return result
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

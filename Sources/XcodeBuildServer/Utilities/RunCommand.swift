//
//  RunCommand.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

func runCommandAsync(_ command: String, arguments: [String] = []) async throws -> String? {
    // Log the command being executed
    let commandString = "\(command) \(arguments.joined(separator: " "))"
    logger.info("Executing command: \(commandString)")

    return try await withCheckedThrowingContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            continuation.resume(returning: String(data: data, encoding: .utf8))
        }

        do {
            try process.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

// run xcodebuild
func xcodebuild(arguments: [String]) async throws -> String? {
    // Log the command being executed
    let commandString = "/usr/bin/xcodebuild \(arguments.joined(separator: " "))"
    logger.info("Executing command: \(commandString)")

    return try await runCommandAsync("/usr/bin/xcodebuild", arguments: arguments)
}

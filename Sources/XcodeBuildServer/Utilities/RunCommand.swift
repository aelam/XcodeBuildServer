//
//  RunCommand.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

import Foundation

func runCommandAsync(_ command: String, arguments: [String] = []) async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
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
    try await runCommandAsync("/usr/bin/xcodebuild", arguments: arguments)
}

import Foundation
import Support

// MARK: - Xcode related

extension ProcessExecutor {
    /// Execute xcodebuild with the given arguments
    /// environments: will set to both Process and xcodebuild
    func executeXcodeBuild(
        arguments: [String],
        workingDirectory: URL? = nil,
        xcodeInstallationPath: URL,
        xcodeBuildEnvironments: [String: String] = [:],
        timeout: TimeInterval? = nil,
        progress: ProcessProgress? = nil
    ) async throws -> ProcessExecutionResult {
        // Use the system xcodebuild (which might be managed by xcenv)
        // instead of forcing a specific path
        let xcodebuildPath = "/usr/bin/xcrun"
        let xcrunArgs = ["xcodebuild"] + arguments

        // Set up Xcode environment - but keep it minimal to avoid conflicts
        var environmentOverrides: [String: String] = [:]

        // Only set DEVELOPER_DIR if it's not already set in the environment
        // This allows xcenv and other tools to work properly
        if ProcessInfo.processInfo.environment["DEVELOPER_DIR"] == nil {
            environmentOverrides["DEVELOPER_DIR"] = xcodeInstallationPath
                .appendingPathComponent("Contents/Developer").path
        }
        environmentOverrides.merge(xcodeBuildEnvironments) { current, _ in current }

        return try await execute(
            executable: xcodebuildPath,
            arguments: xcrunArgs,
            workingDirectory: workingDirectory,
            environment: environmentOverrides,
            timeout: timeout,
            progress: progress
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

import Foundation
import Support

protocol AppInstaller {
    func installApp(
        appPath: String,
        deviceID: String
    ) async throws -> ProcessExecutionResult
}

struct DeviceInstaller: AppInstaller {
    func installApp(
        appPath: String,
        deviceID: String
    ) async throws -> ProcessExecutionResult {
        let executor = ProcessExecutor()
        return try await executor.execute(
            executable: "/usr/bin/xcrun",
            arguments: ["devicectl", "install", "--device", deviceID, "--path", appPath]
        )
    }
}

struct SimulatorInstaller: AppInstaller {
    func installApp(
        appPath: String,
        deviceID: String
    ) async throws -> ProcessExecutionResult {
        let executor = ProcessExecutor()

        _ = try? await executor.execute(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "boot", deviceID]
        )
        return try await executor.execute(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "install", deviceID, appPath]
        )
    }
}

protocol AppLauncher {
    func launchApp(
        deviceID: String,
        appIdentifier: String
    ) async throws -> ProcessExecutionResult
}

struct DeviceLauncher: AppLauncher {
    func launchApp(
        deviceID: String,
        appIdentifier: String
    ) async throws -> ProcessExecutionResult {
        let executor = ProcessExecutor()
        return try await executor.execute(
            executable: "/usr/bin/xcrun",
            arguments: ["devicectl", "launch", "--device", deviceID, "--bundle-id", appIdentifier]
        )
    }
}

struct SimulatorLauncher: AppLauncher {
    func launchApp(
        deviceID: String,
        appIdentifier: String,
    ) async throws -> ProcessExecutionResult {
        let executor = ProcessExecutor()

        var isLaunched = false
        for _ in 0 ..< 30 {
            let result = try await executor.execute(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "launch", "--console", deviceID, appIdentifier]
            )
            if result.exitCode == 0 {
                isLaunched = true
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待 1 秒再试
        }

        if !isLaunched {
            throw XcodeRunError.failedToLaunchApp("Failed to launch app \(appIdentifier) on simulator \(deviceID)")
        } else {
            return ProcessExecutionResult(output: "App launched", error: nil, exitCode: 0)
        }
    }
}

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

        _ = try await executor.execute(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "boot", deviceID]
        )
        return try await executor.execute(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "install", deviceID, appPath]
        )
    }
}

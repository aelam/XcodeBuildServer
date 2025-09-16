import Foundation
import Logger
import PathKit
import Support
import XcodeProj

extension XcodeProjectManager {
    public func test(
        xcodeTargetIdentifiers: [XcodeTargetIdentifier],
        arguments: [String]?, // e.g. ["-configuration", "Debug"]
        environmentVariables: [String: String]?,
        workingDirectory: URL?
    ) async -> XcodeRunResult {
        guard
            let xcodeTargetIdentifier = xcodeTargetIdentifiers.first,
            let xcodeProjectBaseInfo,
            let xcodeProj = loadXcodeProjCache(projectURL: URL(fileURLWithPath: xcodeTargetIdentifier.projectFilePath))
        else {
            return XcodeRunResult(statusCode: .error, message: "Project not loaded")
        }
        let configuration = getConfiguration(from: arguments)

        let buildSettings: [String: String]
        do {
            buildSettings = try BuildSettingResolver(
                xcodeInstallation: xcodeProjectBaseInfo.xcodeInstallation,
                xcodeGlobalSettings: xcodeProjectBaseInfo.xcodeGlobalSettings,
                xcodeProj: xcodeProj,
                target: xcodeTargetIdentifier.targetName,
                configuration: configuration
            ).resolvedBuildSettings
        } catch {
            return XcodeRunResult(
                statusCode: .error,
                message: "Failed to resolve build settings: \(error.localizedDescription)"
            )
        }

        let xcTestRunPath = getXcTestRunPath(from: buildSettings)

        guard let xcTestRunPath else {
            return XcodeRunResult(
                statusCode: .error,
                message: "TEST_HOST or BUNDLE_LOADER not found in build settings"
            )
        }

        return await runTest(
            xcTestRunPath: xcTestRunPath,
            arguments: arguments,
            environmentVariables: environmentVariables,
            workingDirectory: workingDirectory
        )
    }

    private func getConfiguration(from arguments: [String]?) -> String {
        if let arguments,
           let index = arguments.firstIndex(of: "-configuration"),
           index < arguments.count - 1 {
            arguments[index + 1]
        } else if let configuration = xcodeProjectBaseInfo?.configuration {
            configuration
        } else {
            "Debug"
        }
    }

    private func getDestination(from arguments: [String]?) -> String? {
        if let arguments,
           let index = arguments.firstIndex(of: "-destination"),
           index < arguments.count - 1 {
            return arguments[index + 1]
        }
        return nil
    }

    private func getXcTestFilePath(from settings: [String: String]) -> String? {
        if let testHost = settings["TEST_HOST"], !testHost.isEmpty {
            return testHost
        } else if let bundleLoader = settings["BUNDLE_LOADER"], !bundleLoader.isEmpty {
            return bundleLoader
        }
        return nil
    }

    private func getXcTestRunPath(from settings: [String: String]) -> String? {
        // {ProductName}_iphonesimulator18.5-arm64.xctestrun
        guard let builtProductsDir = settings["BUILT_PRODUCTS_DIR"],
              let targetName = settings["TARGET_NAME"],
              let builtProductsDirURL = URL(string: builtProductsDir),
              let sdkName = settings["PLATFORM_NAME"],
              let sdkVersion = settings["SDK_VERSION"],
              let arch = settings["ARCHS"]
        else {
            return nil
        }
        let archString = arch.replacingOccurrences(of: " ", with: "-")
        let xctestrunFileName = "\(targetName)_\(sdkName)\(sdkVersion)-\(archString).xctestrun"
        return builtProductsDirURL
            .deletingLastPathComponent()
            .appendingPathComponent(xctestrunFileName).path
    }

    private func runTest(
        xcTestRunPath: String,
        arguments: [String]?,
        environmentVariables: [String: String]?,
        workingDirectory: URL?
    ) async -> XcodeRunResult {
        // Implement the logic to run the test using the provided paths and parameters
        var testArguments: [String] = []
        testArguments.append(contentsOf: ["xcodebuild", "test-without-building"])
        testArguments.append(contentsOf: ["-xctestrun", xcTestRunPath])
        if let destination = getDestination(from: arguments) {
            testArguments.append(contentsOf: ["-destination", destination])
        }

        let processExecutor = ProcessExecutor()
        let result = try? await processExecutor.execute(
            executable: "/usr/bin/xcrun",
            arguments: testArguments,
            workingDirectory: workingDirectory,
            environment: environmentVariables ?? [:],
            timeout: nil
        )

        return result?.exitCode == 0
            ? XcodeRunResult(statusCode: .success, message: "Test run successful")
            : XcodeRunResult(statusCode: .error, message: "Test run failed")
    }
}

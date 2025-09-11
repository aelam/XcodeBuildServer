import Foundation
import Logger
import PathKit
import Support
import XcodeProj

enum XcodeRunError: Error {
    case projectNotLoaded
    case appNotFound(String)
    case simulatorNotFound(String)
    case deviceNotFound(String)
    case failedToLaunchApp(String)
    case cancelled
}

public struct XcodeRunResult {
    public let status: Int
    public let message: String?
}

extension XcodeProjectManager {
    public func run(
        xcodeTargetIdentifier: XcodeTargetIdentifier,
        arguments: [String]?, // e.g. ["-configuration", "Debug"]
        environmentVariables: [String: String]?,
        workingDirectory: URL?
    ) async throws -> XcodeRunResult {
        guard
            let xcodeProjectBaseInfo,
            let target = xcodeProjectBaseInfo.xcodeTargets
            .first(where: { $0.targetIdentifier == xcodeTargetIdentifier }),
            let xcodeProj = loadXcodeProjCache(projectURL: URL(fileURLWithPath: xcodeTargetIdentifier.projectFilePath))
        else {
            throw XcodeRunError.projectNotLoaded
        }
        let configuration = getConfiguration(from: arguments)

        let buildSettings = try BuildSettingResolver(
            xcodeInstallation: xcodeProjectBaseInfo.xcodeInstallation,
            xcodeGlobalSettings: xcodeProjectBaseInfo.xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: xcodeTargetIdentifier.targetName,
            configuration: configuration
        ).resolvedBuildSettings

        guard
            let platformName = buildSettings["PLATFORM_NAME"],
            let sdk = XcodeSDK(rawValue: platformName)
        else {
            throw XcodeRunError.failedToLaunchApp("PLATFORM_NAME not found in build settings")
        }

        logger.info("Build settings loaded., \(buildSettings)")
        guard let binaryPath = getOutputPath(
            buildSettings: buildSettings,
            productType: target.xcodeProductType
        ) else {
            throw XcodeRunError.appNotFound("App binary not found for target \(xcodeTargetIdentifier.rawValue)")
        }
        logger.info("Binary path: \(binaryPath)")

        if sdk == .macOS {
            logger.info("Running on macOS")
            let result = try await runOnMac(binaryPath: binaryPath)
            return XcodeRunResult(
                status: Int(result.exitCode),
                message: result.output
            )
        } else if sdk == .iOS || sdk == .tvOS || sdk == .watchOS {
            // real device
            throw XcodeRunError.failedToLaunchApp("Only macOS apps are supported currently")
        } else if sdk == .iOSSimulator || sdk == .tvSimulator || sdk == .watchSimulator {
            // simulator
            throw XcodeRunError.failedToLaunchApp("Only macOS apps are supported currently")
        } else {
            throw XcodeRunError.failedToLaunchApp("Unsupported SDK: \(platformName)")
        }
    }

    private func getOutputPath(
        buildSettings: [String: String],
        productType: XcodeProductType
    ) -> String? {
        guard
            let buildDir = buildSettings["CONFIGURATION_BUILD_DIR"],
            let productName = buildSettings["PRODUCT_NAME"]
        else {
            return nil
        }

        return if let fileExtension = productType.fileExtension {
            [
                buildDir,
                productName + "." + fileExtension, "Contents/MacOS",
                productName
            ].joined(separator: "/")
        } else {
            [
                buildDir,
                productName
            ].joined(separator: "/")
        }
    }

    private var isInstallRequired: Bool {
        true
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

    private func runOnMac(binaryPath: String) async throws -> ProcessExecutionResult {
        let executor = ProcessExecutor()
        return try await executor.execute(
            executable: binaryPath,
            arguments: [],
            workingDirectory: nil,
            environment: [:],
            progress: nil
        )
    }
}

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
            productType: target.xcodeProductType,
            isMacApp: sdk == .macOS
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
        }

        guard let destinationID = getDestination(from: arguments) else {
            throw XcodeRunError
                .failedToLaunchApp("Destination ID not found. Please specify -destination id=XXXX in arguments")
        }

        if sdk == .iOS || sdk == .tvOS || sdk == .watchOS {
            // real device
            try await installOnNonMac(isSimulator: false, outputPath: binaryPath, deviceID: destinationID)
            try await runOnDevice(deviceID: destinationID)
            throw XcodeRunError.failedToLaunchApp("Testing on real device")
        } else if sdk == .iOSSimulator || sdk == .tvSimulator || sdk == .watchSimulator {
            // simulator
            try await installOnNonMac(isSimulator: true, outputPath: binaryPath, deviceID: destinationID)
            try await runOnSimulator(simulatorID: destinationID)
            throw XcodeRunError.failedToLaunchApp("Testing on simulator")
        } else {
            throw XcodeRunError.failedToLaunchApp("Unsupported SDK: \(platformName)")
        }
    }

    private func getOutputPath(
        buildSettings: [String: String],
        productType: XcodeProductType,
        isMacApp: Bool = true
    ) -> String? {
        guard
            let buildDir = buildSettings["CONFIGURATION_BUILD_DIR"],
            let productName = buildSettings["PRODUCT_NAME"]
        else {
            return nil
        }

        let components: [String] = if let fileExtension = productType.fileExtension {
            if isMacApp {
                [
                    buildDir,
                    productName + "." + fileExtension,
                    isMacApp ? "Contents/MacOS" : "Contents/Resources",
                    productName
                ]
            } else {
                [
                    buildDir,
                    productName + "." + fileExtension
                ]
            }
        } else {
            [
                buildDir,
                productName
            ]
        }

        return components.joined(separator: "/")
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
            let destination = arguments[index + 1]
            if destination.starts(with: "id=") {
                return String(destination.dropFirst(3))
            }
            return nil
        }
        return nil
    }

    // MARK: - Run on Mac

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

    // MARK: simulators / real device

    private func installOnNonMac(isSimulator: Bool, outputPath: String, deviceID: String) async throws {
        let installer: AppInstaller = isSimulator ? SimulatorInstaller() : DeviceInstaller()
        _ = try await installer.installApp(
            appPath: outputPath,
            deviceID: deviceID
        )
    }

    private func runOnSimulator(simulatorID: String?) async throws {
        // TODO: implement running on simulator
    }

    private func runOnDevice(deviceID: String?) async throws {
        // TODO: implement running on device
    }
}

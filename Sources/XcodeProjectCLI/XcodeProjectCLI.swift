//
//  XcodeProjectCLI.swift
//
//  Copyright © 2024 Wang Lun.
//
//  Example usage of the XcodeProjectManagement module

import Foundation
import Logger
import XcodeProjectManagement

@main
struct XcodeProjectCLI {
    static func main() async {
        guard CommandLine.arguments.count > 1 else {
            logger.error("Usage: XcodeProjectCLI <project_path>")
            return
        }

        let projectPath = CommandLine.arguments[1]
        let projectURL = URL(fileURLWithPath: projectPath)

        do {
            let toolchain = XcodeToolchain()
            // Initialize the project manager
            let projectManager = XcodeProjectManager(
                rootURL: projectURL,
                xcodeProjectReference: nil,
                toolchain: toolchain,
                locator: XcodeProjectLocator(),
                settingsLoader: XcodeSettingsLoader(
                    commandBuilder: XcodeBuildCommandBuilder(),
                    toolchain: toolchain
                )
            )

            try await projectManager.initialize()

            // Load the project
            let timestamp = Date()
            print("Loading Xcode project at: \(timestamp)")
            print("Loading Xcode project from: \(projectPath)")
            let project = try await projectManager.resolveXcodeProjectInfo()

            print("✓ Project loaded successfully")
            let baseProjectInfo = project.baseProjectInfo
            print("  - Root URL: \(baseProjectInfo.rootURL.path)")
            print("  - Scheme Name: \(baseProjectInfo.importantScheme.name)")
            print(" - Project Targets: \(project.baseProjectInfo.xcodeTargets.map(\.name).joined(separator: ", "))")

            // Targets
            print("\n✅🗂️ Target Information:")
            for target in project.baseProjectInfo.xcodeTargets {
                print("  - Target Name: \(target.name)")
                print("  - Is Test: \(target.xcodeProductType.asProductType.isTestType)")
                print("  - Is Runnable: \(target.xcodeProductType.asProductType.isRunnableType)")
            }

            // Show indexing paths
            let xcodeProjectBuildSettings = project.baseProjectInfo.xcodeProjectBuildSettings
            print("\n✅🗂️ Indexing Information:")
            print("  - Index Store URL: \(xcodeProjectBuildSettings.indexStoreURL.path)")
            print("  - Index Database URL: \(xcodeProjectBuildSettings.indexDatabaseURL.path)")
            print("  - Derived Data Path: \(xcodeProjectBuildSettings.derivedDataPath.path)")
            print("  - Configuration: \(project.baseProjectInfo.configuration)")
            let endTimestamp = Date()
            print("Loading time: \(endTimestamp.timeIntervalSince(timestamp)) seconds")
        } catch {
            print("❌ Error: \(error)")
        }
    }
}

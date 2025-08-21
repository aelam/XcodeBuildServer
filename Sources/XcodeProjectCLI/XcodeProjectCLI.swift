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
            try await toolchain.initialize()

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

            // Load the project
            let timestamp = Date()
            logger.info("Loading Xcode project at: \(timestamp)")
            logger.info("Loading Xcode project from: \(projectPath)")
            let project = try await projectManager.resolveXcodeProjectInfo()

            logger.info("✓ Project loaded successfully")
            logger.info("  - Root URL: \(project.rootURL.path)")
            logger.info("  - Project Name: \(project.name)")
            logger.info("  - Scheme Name: \(project.importantScheme.name)")
            logger.info(" - Project Targets: \(project.xcodeTargets.map(\.name).joined(separator: ", "))")

            // Targets
            logger.info("\n✅🗂️ Target Information:")
            for target in project.xcodeTargets {
                logger.info("  - Target Name: \(target.name)")
                logger.info("  - Is Test: \(target.xcodeProductType.isTestType)")
                logger.info("  - Is Runnable: \(target.xcodeProductType.isRunnableType)")
            }

            // Show indexing paths
            let xcodeProjectBuildSettings = project.xcodeProjectBuildSettings
            logger.info("\n✅🗂️ Indexing Information:")
            logger.info("  - Index Store URL: \(xcodeProjectBuildSettings.indexStoreURL.path)")
            logger.info("  - Index Database URL: \(xcodeProjectBuildSettings.indexDatabaseURL.path)")
            logger.info("  - Derived Data Path: \(xcodeProjectBuildSettings.derivedDataPath.path)")
            logger.info("  - Configuration: \(xcodeProjectBuildSettings.configuration)")

            let endTimestamp = Date()
            logger.info("Loading time: \(endTimestamp.timeIntervalSince(timestamp)) seconds")
        } catch {
            logger.error("❌ Error: \(error)")
        }
    }
}

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
            let project = try await projectManager.resolveProjectInfo()

            logger.info("✓ Project loaded successfully")
            logger.info("  - Root URL: \(project.rootURL.path)")
            // logger.info("  - Project Type: \(project.projectType.rawValue)")
            logger.info("  - Project Name: \(project.name)")
            // logger.info("  - Schemes: \(project.schemeInfoList.map(\.name).joined(separator: ", "))")
            // logger.info("  - Targets: \(project.targetInfoList.map(\.name).joined(separator: ", "))")

            // Targets
            logger.info("\n🗂️ Target Information:")
            for target in project.targets {
                logger.info("  - Target Name: \(target.name)")
                logger.info("  - Is Test: \(target.productType.isTestType)")
                logger.info("  - Is Runnable: \(target.productType.isRunnableType)")
            }

            // Show indexing paths
            logger.info("\n🗂️ Indexing Information:")
            logger.info("  - Index Store URL: \(project.primaryBuildSettings.indexStoreURL.path)")
            logger.info("  - Index Database URL: \(project.primaryBuildSettings.indexDatabaseURL.path)")
            logger.info("  - Derived Data Path: \(project.primaryBuildSettings.derivedDataPath.path)")
            logger.info("  - Configuration: \(project.primaryBuildSettings.configuration)")

            let endTimestamp = Date()
            logger.info("Loading time: \(endTimestamp.timeIntervalSince(timestamp)) seconds")
        } catch {
            logger.error("❌ Error: \(error)")
        }
    }
}

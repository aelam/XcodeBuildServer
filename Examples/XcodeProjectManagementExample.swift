//
//  XcodeProjectManagementExample.swift
//
//  Copyright © 2024 Wang Lun.
//
//  Example usage of the XcodeProjectManagement module

import Foundation
import XcodeProjectManagement

@main
struct XcodeProjectManagementExample {
    static func main() async {
        guard CommandLine.arguments.count > 1 else {
            print("Usage: XcodeProjectManagementExample <project_path>")
            return
        }

        let projectPath = CommandLine.arguments[1]
        let projectURL = URL(fileURLWithPath: projectPath)

        do {
            // Initialize the project manager
            let projectManager = XcodeProjectManager(
                rootURL: projectURL,
                xcodeProjectReference: nil,
                toolchain: XcodeToolchain(),
                locator: XcodeProjectLocator(),
                settingsLoader: XcodeSettingsLoader(),
                commandBuilder: XcodeBuildCommandBuilder()
            )

            // Load the project
            print("Loading Xcode project from: \(projectPath)")
            let project = try await projectManager.resolveProjectInfo()

            print("✓ Project loaded successfully")
            print("  - Root URL: \(project.rootURL.path)")
            print("  - Workspace: \(project.workspaceURL.path)")
            print("  - Schemes: \(project.schemeInfoList.map(\.name).joined(separator: ", "))")

            let commandBuilder = XcodeBuildCommandBuilder()

            // Generate various commands
            print("\n📋 Available Commands:")

            if let firstScheme = project.schemeInfoList.first {
                let buildCommand = commandBuilder.buildCommand(
                    scheme: firstScheme.name,
                    configuration: firstScheme.configuration ?? "Debug",
                    options: XcodeBuildOptions.build
                )
                print("Build command: xcodebuild \(buildCommand.joined(separator: " "))")

                let settingsCommand = commandBuilder.buildCommand(
                    scheme: firstScheme.name,
                    configuration: firstScheme.configuration ?? "Debug",
                    options: XcodeBuildOptions.buildSettingsJSON()
                )
                print("Build settings command: xcodebuild \(settingsCommand.joined(separator: " "))")

                print("✓ Example commands generated for scheme: \(firstScheme.name)")
            } else {
                print("No schemes found in project")
            }

            // Show indexing paths
            print("\n🗂️ Indexing Information:")
            print("  - Index Store URL: \(project.indexStoreURL.path)")
            print("  - Index Database URL: \(project.indexDatabaseURL.path)")
            print("  - Derived Data Path: \(project.derivedDataPath.path)")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}

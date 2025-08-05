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
            let manager = XcodeProjectManager(rootURL: projectURL)

            // Load the project
            print("Loading Xcode project from: \(projectPath)")
            let project = try await manager.loadProject()

            print("✓ Project loaded successfully")
            print("  - Root URL: \(project.rootURL.path)")
            print("  - Workspace: \(project.workspaceName)")
            print("  - Project: \(project.projectName ?? "N/A")")
            print("  - Scheme: \(project.scheme ?? "N/A")")
            print("  - Configuration: \(project.configuration)")

            // Create command builder
            let commandBuilder = XcodeBuildCommandBuilder(projectInfo: project)

            // Generate various commands
            print("\n📋 Available Commands:")

            let buildCommand = commandBuilder.buildCommand(
                action: .build,
                destination: .iOSSimulator
            )
            print("Build command: xcodebuild \(buildCommand.joined(separator: " "))")

            let settingsCommand = commandBuilder.buildSettingsCommand()
            print("Build settings command: xcodebuild \(settingsCommand.joined(separator: " "))")

            let bspCommand = commandBuilder.buildForBSP()
            print("BSP build command: xcodebuild \(bspCommand.joined(separator: " "))")

            // Initialize settings manager
            let settingsManager = XcodeSettingsManager(commandBuilder: commandBuilder)

            print("\n⚙️ Loading build settings...")
            try await settingsManager.loadBuildSettings()
            try await settingsManager.loadBuildSettingsForIndex()

            if let scheme = project.scheme {
                try await settingsManager.loadIndexingPaths(scheme: scheme)
                print("✓ Settings loaded for scheme: \(scheme)")

                // Example of getting compile arguments
                let sampleFile = "file://\(projectURL.path)/Sample.swift"
                let compileArgs = settingsManager.getCompileArguments(fileURI: sampleFile, scheme: scheme)
                if !compileArgs.isEmpty {
                    print("  - Compile arguments for \(sampleFile): \(compileArgs.joined(separator: " "))")
                } else {
                    print("  - No compile arguments found for sample file")
                }
            }

        } catch {
            print("❌ Error: \(error)")
        }
    }
}

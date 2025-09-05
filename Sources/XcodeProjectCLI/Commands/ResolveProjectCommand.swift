//
//  ResolveProjectCommand.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/09/04.
//

import ArgumentParser
import Foundation
import XcodeProjectManagement

struct ResolveProjectCommand: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Xcode project/workspace folder path")
    var workspaceFolder: String

    static let configuration = CommandConfiguration(
        commandName: "resolveProject",
        abstract: "resolveProject: Resolve Xcode Project/Workspace"
    )

    mutating func run() async throws {
        try await resolveProject()
    }

    private func resolveProject() async throws {
        let workspaceFolder = workspaceFolder.absolutePath
        let rootURL = URL(fileURLWithPath: workspaceFolder)

        let preferredProjectInfoURL = rootURL.appendingPathComponent(".XcodeBuildServer/project.json")
        let xcodeProjectReference: XcodeProjectReference? =
            try? JSONDecoder().decode(
                XcodeProjectReference.self,
                from: Data(contentsOf: preferredProjectInfoURL)
            )

        let toolchain = XcodeToolchain()
        let projectManager = XcodeProjectManager(
            rootURL: rootURL,
            xcodeProjectReference: xcodeProjectReference,
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
        print("Loading Xcode project from: \(workspaceFolder)")
        guard let baseProjectInfo = await projectManager.xcodeProjectBaseInfo else {
            print("❌ Project loaded Failed")
            return
        }
        print("✅ Project loaded successfully")

        print("  - Root URL: \(baseProjectInfo.rootURL.path)")
        print("  - Project Configuration: \(baseProjectInfo.configuration)")
        print(
            " - Project Targets: \(baseProjectInfo.xcodeTargets.map(\.name).joined(separator: ", "))"
        )

        // Targets
        print("\n✅🗂️ Target Information:")
        for target in baseProjectInfo.xcodeTargets {
            print("  - Target Name: \(target.name)")
            print("  - xcodeProductType: \(target.xcodeProductType)")
        }

        // Show indexing paths
        let xcodeGlobalSettings = baseProjectInfo.xcodeGlobalSettings
        print("\n✅🗂️ Indexing Information:")
        print("  - Index Store URL: \(xcodeGlobalSettings.indexStoreURL.path)")
        print("  - Index Database URL: \(xcodeGlobalSettings.indexDatabaseURL.path)")
        print("  - Derived Data Path: \(xcodeGlobalSettings.derivedDataPath.path)")
        print("  - Configuration: \(baseProjectInfo.configuration)")
        let targetIdentifiers = baseProjectInfo.xcodeTargets.map(\.targetIdentifier)
        let sourcesItems = await projectManager
            .getSourcesItems(targetIdentifiers: targetIdentifiers)
        for sourcesItem in sourcesItems {
            print("Sources for target \(sourcesItem.target):")
            for source in sourcesItem.sources {
                print(" - \(source.path)")
            }
        }

        let endTimestamp = Date()
        print("Loading time: \(endTimestamp.timeIntervalSince(timestamp)) seconds")
    }
}

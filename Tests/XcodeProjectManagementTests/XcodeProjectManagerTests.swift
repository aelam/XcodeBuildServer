//
//  XcodeProjectManagerTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeProjectManagerTests {
    @Test
    func loadProjectFromWorkspace() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloWorkspace")

        let toolchain = XcodeToolchain()
        let projectManager = XcodeProjectManager(
            rootURL: projectFolder,
            toolchain: toolchain,
            locator: XcodeProjectLocator(),
            settingsLoader: XcodeSettingsLoader(
                commandBuilder: XcodeBuildCommandBuilder(),
                toolchain: toolchain
            )
        )
        try await projectManager.initialize()
        let project = try await projectManager.resolveXcodeProjectInfo()

        #expect(project.baseProjectInfo.rootURL == projectFolder)

        switch project.baseProjectInfo.projectLocation {
        case let .explicitWorkspace(url):
            #expect(url.lastPathComponent == "Hello.xcworkspace")
        case .implicitWorkspace:
            Issue.record("Expected explicit workspace, got implicit project workspace")
        case .standaloneProject:
            Issue.record("Expected explicit workspace, got standalone project")
        }
    }

    @Test
    func loadProjectFromXcodeproj() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let toolchain = XcodeToolchain()
        let projectManager = XcodeProjectManager(
            rootURL: projectFolder,
            toolchain: toolchain,
            locator: XcodeProjectLocator(),
            settingsLoader: XcodeSettingsLoader(
                commandBuilder: XcodeBuildCommandBuilder(),
                toolchain: toolchain
            )
        )
        try await projectManager.initialize()
        let projectInfo = try await projectManager.resolveXcodeProjectInfo()

        #expect(projectInfo.baseProjectInfo.rootURL == projectFolder)

        switch projectInfo.baseProjectInfo.projectLocation {
        case .explicitWorkspace:
            Issue.record("Expected implicit project workspace, got explicit workspace")
        case let .implicitWorkspace(_, url):
            #expect(url.path.contains("Hello.xcodeproj/project.xcworkspace"))
        case .standaloneProject:
            Issue.record("Expected implicit project workspace, got standalone project")
        }
    }
}

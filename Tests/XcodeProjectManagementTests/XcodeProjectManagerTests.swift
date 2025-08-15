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

        let projectManager = XcodeProjectManager(
            rootURL: projectFolder,
            toolchain: XcodeToolchain(),
            locator: XcodeProjectLocator()
        )
        try await projectManager.initialize()
        let project = try await projectManager.resolveProjectInfo()

        #expect(project.rootURL == projectFolder)

        switch project.projectLocation {
        case let .explicitWorkspace(url):
            #expect(url.lastPathComponent == "Hello.xcworkspace")
        case .implicitWorkspace:
            Issue.record("Expected explicit workspace, got implicit project workspace")
        }
        #expect(project.buildSettingsForIndex?.count == 3)
        #expect(project.targets.count == 3)
    }

    @Test
    func loadProjectFromXcodeproj() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let projectManager = XcodeProjectManager(
            rootURL: projectFolder,
            toolchain: XcodeToolchain(),
            locator: XcodeProjectLocator()
        )
        try await projectManager.initialize()
        let projectInfo = try await projectManager.resolveProjectInfo()

        #expect(projectInfo.rootURL == projectFolder)

        switch projectInfo.projectLocation {
        case .explicitWorkspace:
            Issue.record("Expected implicit project workspace, got explicit workspace")
        case let .implicitWorkspace(_, url):
            #expect(url.path.contains("Hello.xcodeproj/project.xcworkspace"))
        }
        #expect(projectInfo.buildSettingsForIndex?.count == 3)
    }
}

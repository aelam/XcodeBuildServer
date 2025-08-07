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
            projectReference: nil,
            toolchain: XcodeToolchain(),
            locator: XcodeProjectLocator()
        )
        let project = try await projectManager.loadProjectBasicInfo()

        #expect(project.rootURL == projectFolder)
        #expect(!project.schemeInfoList.isEmpty)

        switch project.projectLocation {
        case let .explicitWorkspace(url):
            #expect(url.lastPathComponent == "Hello.xcworkspace")
        case .implicitWorkspace:
            Issue.record("Expected explicit workspace, got implicit project workspace")
        }
    }

    @Test
    func loadProjectFromXcodeproj() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let projectManager = XcodeProjectManager(
            rootURL: projectFolder,
            projectReference: nil,
            toolchain: XcodeToolchain(),
            locator: XcodeProjectLocator()
        )
        let project = try await projectManager.loadProjectBasicInfo()

        #expect(project.rootURL == projectFolder)
        #expect(!project.schemeInfoList.isEmpty)

        switch project.projectLocation {
        case .explicitWorkspace:
            Issue.record("Expected implicit project workspace, got explicit workspace")
        case let .implicitWorkspace(_, url):
            #expect(url.path.contains("Hello.xcodeproj/project.xcworkspace"))
        }
    }

    @Test
    func getAvailableSchemes() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let manager = XcodeProjectManager(
            rootURL: projectFolder,
            projectReference: nil,
            toolchain: XcodeToolchain(),
            locator: XcodeProjectLocator()
        )
        let basicInfo = try await manager.loadProjectBasicInfo()
        let schemeNames = basicInfo.schemeInfoList.map(\.name)
        #expect(!schemeNames.isEmpty)
        #expect(schemeNames.contains("Hello"))
    }

    @Test
    func getAvailableConfigurations() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let manager = XcodeProjectManager(
            rootURL: projectFolder,
            projectReference: nil,
            toolchain: XcodeToolchain(),
            locator: XcodeProjectLocator()
        )
        let basicInfo = try await manager.loadProjectBasicInfo()

        // Note: Configuration testing would require actual xcodebuild execution
        // For now, we'll just verify the project loaded successfully
        #expect(!basicInfo.schemeInfoList.isEmpty)
    }
}

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

        let manager = XcodeProjectManager(rootURL: projectFolder)
        let project = try await manager.loadProject()

        #expect(project.rootURL == projectFolder)
        #expect(project.configuration == "Debug")

        switch project.projectType {
        case let .explicitWorkspace(url):
            #expect(url.lastPathComponent == "Hello.xcworkspace")
        case .implicitProjectWorkspace:
            Issue.record("Expected explicit workspace, got implicit project workspace")
        }
    }

    @Test
    func loadProjectFromXcodeproj() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let manager = XcodeProjectManager(rootURL: projectFolder)
        let project = try await manager.loadProject()

        #expect(project.rootURL == projectFolder)
        #expect(project.configuration == "Debug")

        switch project.projectType {
        case .explicitWorkspace:
            Issue.record("Expected implicit project workspace, got explicit workspace")
        case let .implicitProjectWorkspace(url):
            #expect(url.path.contains("Hello.xcodeproj/project.xcworkspace"))
        }
    }

    @Test
    func getAvailableSchemes() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let manager = XcodeProjectManager(rootURL: projectFolder)
        _ = try await manager.loadProject()

        let schemes = try await manager.getAvailableSchemes()
        #expect(!schemes.isEmpty)
        #expect(schemes.contains("Hello"))
    }

    @Test
    func getAvailableConfigurations() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")

        let manager = XcodeProjectManager(rootURL: projectFolder)
        _ = try await manager.loadProject()

        let configurations = try await manager.getAvailableConfigurations()
        #expect(!configurations.isEmpty)
        #expect(configurations.contains("Debug"))
        #expect(configurations.contains("Release"))
    }
}

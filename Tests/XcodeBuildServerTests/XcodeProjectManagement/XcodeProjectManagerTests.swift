//
//  XcodeProjectManagerTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

private func isXcodeBuildAvailable() -> Bool {
    // First check if xcodebuild exists
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["xcodebuild"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return false }
    } catch {
        return false
    }

    // Then check if xcodebuild can actually run (test with -version)
    let testProcess = Process()
    testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    testProcess.arguments = ["-version"]

    let testPipe = Pipe()
    testProcess.standardOutput = testPipe
    testProcess.standardError = testPipe

    do {
        try testProcess.run()
        testProcess.waitUntilExit()
        return testProcess.terminationStatus == 0
    } catch {
        return false
    }
}

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

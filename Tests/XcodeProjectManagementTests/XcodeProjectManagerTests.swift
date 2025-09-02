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
        let projectFolder = Bundle.module.url(
            forResource: "HelloWorkspace",
            withExtension: nil,
            subdirectory: "Resources/DemoProjects"
        )!

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
        guard let xcodeProjectBaseInfo = await projectManager.xcodeProjectBaseInfo else {
            throw NSError(domain: "XcodeProjectManagerTests", code: 1, userInfo: nil)
        }

        #expect(xcodeProjectBaseInfo.rootURL == projectFolder)

        switch xcodeProjectBaseInfo.projectLocation {
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
        let projectFolder = Bundle.module.url(
            forResource: "HelloProject",
            withExtension: nil,
            subdirectory: "Resources/DemoProjects"
        )!
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
        guard let xcodeProjectBaseInfo = await projectManager.xcodeProjectBaseInfo else {
            throw NSError(domain: "XcodeProjectManagerTests", code: 1, userInfo: nil)
        }
        #expect(xcodeProjectBaseInfo.rootURL == projectFolder)

        switch xcodeProjectBaseInfo.projectLocation {
        case .explicitWorkspace:
            Issue.record("Expected implicit project workspace, got explicit workspace")
        case let .implicitWorkspace(_, url):
            #expect(url.path.contains("Hello.xcodeproj/project.xcworkspace"))
        case .standaloneProject:
            Issue.record("Expected implicit project workspace, got standalone project")
        }
    }
}

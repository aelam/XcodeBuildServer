//
//  XcodeProjectLocatorTests.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/04.
//

import Foundation
import Testing

/// `.bsp/xcode.json`
@testable import XcodeProjectManagement

struct XcodeProjectLocatorTests {
    @Test(arguments: [
        ("HelloWorkspace", "Hello.xcworkspace"),
        ("HelloProject", "Hello.xcproje/Project.xcworkspace"),
    ])
    func xcodeProjectLocator(_ root: String, _ suffix: String) throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent(root)
        let locator = XcodeProjectLocator()
        let projectLocation = try locator.resolveProjectType(rootURL: projectFolder)
        #expect(projectLocation.workspaceURL.path.hasSuffix(suffix))
    }

    @Test
    func xcodeProjectLocatorNoProjectFile() throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("NoProjectFile")
        let locator = XcodeProjectLocator()
        do {
            _ = try locator.resolveProjectType(rootURL: projectFolder)
            Issue.record("Expected .projectNotFound error")
        } catch {
            let xcodeError = try #require(error as? XcodeProjectError)
            #expect(xcodeError == .projectNotFound)
        }
    }
}

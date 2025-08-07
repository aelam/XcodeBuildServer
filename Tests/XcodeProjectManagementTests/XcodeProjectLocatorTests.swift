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
        ("HelloWorkspace", "workspace"),
        ("HelloProject", "project"),
    ])
    func xcodeProjectLocator(_ root: String, _ expectedKind: String) throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent(root)
        let locator = XcodeProjectLocator()
        let projectType = try locator.resolveProjectType(rootURL: projectFolder)
        let actualKind = switch projectType {
        case .explicitWorkspace:
            "workspace"
        case .implicitProjectWorkspace:
            "project"
        }
        #expect(actualKind == expectedKind)
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

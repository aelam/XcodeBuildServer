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
        print(projectFolder)
        let locator = XcodeProjectLocator(root: projectFolder)
        let bspConfig = try locator.resolveProject()
        let actualKind = switch bspConfig {
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
        let locator = XcodeProjectLocator(root: projectFolder)
        do {
            _ = try locator.resolveProject()
            #expect(false, "Expected .notFound error")
        } catch {
            let xcodeError = try #require(error as? XcodeProjectError)
            #expect(xcodeError == .notFound)
        }
    }
}

//
//  XcodeProjectLocatorTests.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/04.
//

/// `.bsp/xcode.json`
@testable import XcodeBuildServer
import Foundation
import Testing

struct XcodeProjectLocatorTests {
    @Test(arguments: [
        ("DemoProjects/HelloWorkspace", "workspace"),
        ("DemoProjects/HelloProject", "project"),
    ])
    func testXcodeProjectLocator(_ root: String, _ expectedKind: String) throws {
        let projectFolder = URL(string: #filePath)!
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(root)
        print(projectFolder)
        let locator = XcodeProjectLocator(root: projectFolder)
        let bspConfig = try locator.resolveProject()
        let actualKind: String
        switch bspConfig {
        case .explicitWorkspace:
            actualKind = "workspace"
        case .implicitProjectWorkspace:
            actualKind = "project"
        }
        #expect(actualKind == expectedKind)
    }
}

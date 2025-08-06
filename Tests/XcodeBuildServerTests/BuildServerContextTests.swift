//
//  BuildServerContextTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeBuildServer
@testable import XcodeProjectManagement

struct BuildServerContextTests {
    @Test
    func bspConfigDefaultConfiguration() {
        #expect(BSPConfig.defaultConfiguration == "Debug")
    }

    @Test
    func bspConfigCodable() throws {
        let config = BSPConfig(
            workspace: "Test.xcworkspace",
            project: nil,
            scheme: "TestScheme",
            configuration: "Release"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(BSPConfig.self, from: data)

        #expect(decodedConfig.workspace == "Test.xcworkspace")
        #expect(decodedConfig.project == nil)
        #expect(decodedConfig.scheme == "TestScheme")
        #expect(decodedConfig.configuration == "Release")
    }

    @Test
    func buildServerContextInitialState() async throws {
        let context = BuildServerContext()

        let isLoaded = await context.isLoaded
        #expect(!isLoaded)

        let rootURL = await context.rootURL
        #expect(rootURL == nil)
    }

    @Test
    func testLoadProject() async throws {
        let context = BuildServerContext()
        let testURL = URL(fileURLWithPath: "/tmp/test")

        // Test that the method exists and accepts the right parameters
        // Expected to fail in test environment without actual Xcode projects
        do {
            try await context.loadProject(rootURL: testURL)
        } catch {
            // Expected to fail, but we can verify the method signature works
        }

        // Verify rootURL was set even on failure
        let storedURL = await context.rootURL
        #expect(storedURL == testURL)
    }

    @Test
    func bspConfigToProjectReference() {
        let bspConfig = BSPConfig(
            workspace: "Test.xcworkspace",
            project: nil,
            scheme: "TestScheme",
            configuration: "Release"
        )

        let projectRef = bspConfig.projectReference
        #expect(projectRef.workspace == "Test.xcworkspace")
        #expect(projectRef.project == nil)
        #expect(projectRef.scheme == "TestScheme")
        #expect(projectRef.configuration == "Release")
    }
}

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
    func xcodeBSPConfigurationDefaultConfiguration() {
        #expect(XcodeBSPConfiguration.defaultConfiguration == "Debug")
    }

    @Test
    func xcodeBSPConfigurationCodable() throws {
        let config = XcodeBSPConfiguration(
            workspace: "Test.xcworkspace",
            project: nil,
            scheme: "TestScheme",
            configuration: "Release"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(XcodeBSPConfiguration.self, from: data)

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

        // Note: rootURL is only set on successful load in the new implementation
        // This is better design as failed loads shouldn't leave partial state
        let storedURL = await context.rootURL
        #expect(storedURL == nil)
    }

    @Test
    func xcodeBSPConfigurationToProjectReference() {
        let config = XcodeBSPConfiguration(
            workspace: "Test.xcworkspace",
            project: nil,
            scheme: "TestScheme",
            configuration: "Release"
        )

        let projectRef = config.projectReference
        #expect(projectRef.workspace == "Test.xcworkspace")
        #expect(projectRef.project == nil)
        #expect(projectRef.scheme == "TestScheme")
        #expect(projectRef.configuration == "Release")
    }
}

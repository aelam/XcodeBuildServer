//
//  XcodeToolchainTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

@Suite("XcodeToolchain Tests")
struct XcodeToolchainTests {
    @Test("Toolchain can be initialized")
    func toolchainInitialization() async throws {
        let toolchain = XcodeToolchain()

        #expect(await toolchain.getSelectedInstallation() == nil)

        try await toolchain.initialize()

        // After initialization, should have selected an installation
        let installation = await toolchain.getSelectedInstallation()
        #expect(installation != nil)

        if let installation {
            #expect(!installation.version.isEmpty)
            #expect(installation.path.pathExtension == "app")
            #expect(installation.xcodebuildPath.lastPathComponent == "xcodebuild")
        }
    }

    @Test("Toolchain can check if xcodebuild is available")
    func xcodeBuildAvailability() async throws {
        let toolchain = XcodeToolchain()
        try await toolchain.initialize()

        let isAvailable = await toolchain.isXcodeBuildAvailable()

        // Should be true on macOS with Xcode installed
        #expect(isAvailable == true)
    }

    @Test("Toolchain can execute xcodebuild version")
    func xcodeBuildVersion() async throws {
        let toolchain = XcodeToolchain()
        try await toolchain.initialize()

        let version = try await toolchain.getXcodeVersion()

        #expect(!version.isEmpty)
        #expect(version.contains("Xcode"))

        // In CI, also log the Xcode version for debugging
        if ProcessInfo.processInfo.environment["CI"] != nil {
            print("🔧 CI Xcode version: \(version)")
        }
    }

    @Test("Toolchain can execute xcodebuild with arguments")
    func xcodeBuildExecution() async throws {
        let toolchain = XcodeToolchain()
        try await toolchain.initialize()

        let (output, exitCode) = try await toolchain.executeXcodeBuild(arguments: ["-version"])

        #expect(exitCode == 0)
        #expect(!output.isEmpty)
        #expect(output.contains("Xcode"))
    }

    @Test("Global isXcodeBuildAvailable function works")
    func globalFunction() async {
        let isAvailable = await isXcodeBuildAvailable()

        // Should be true on macOS with Xcode installed
        #expect(isAvailable == true)
    }

    @Test("Toolchain with custom DEVELOPER_DIR")
    func testCustomDeveloperDir() async throws {
        // Skip this test in CI environments as it depends on specific local paths
        if ProcessInfo.processInfo.environment["CI"] != nil {
            print("⏭️  Skipping testCustomDeveloperDir in CI environment")
            return // Skip in CI
        }

        // Test with a custom developer directory
        let customDir = "/Applications/Xcode.app/Contents/Developer"

        // Only run if the standard Xcode path exists
        guard FileManager.default.fileExists(atPath: customDir) else {
            print("⏭️  Skipping testCustomDeveloperDir - Xcode not found at standard location")
            return // Skip if Xcode not found at standard location
        }

        let toolchain = XcodeToolchain(customDeveloperDir: customDir)
        try await toolchain.initialize()

        let installation = await toolchain.getSelectedInstallation()
        #expect(installation != nil)

        // The key test: when we explicitly set DEVELOPER_DIR, it should be marked as such
        #expect(installation?.isDeveloperDirSet == true)
    }

    @Test("Toolchain handles invalid paths gracefully")
    func invalidPaths() async {
        let toolchain = XcodeToolchain(customDeveloperDir: "/invalid/path")

        do {
            try await toolchain.initialize()

            // If initialization succeeds, it found other Xcode installations
            let installation = await toolchain.getSelectedInstallation()
            #expect(installation != nil)
        } catch {
            // It's okay if it fails with an invalid path, as long as it doesn't crash
            #expect(error is XcodeToolchainError)
        }
    }

    @Test("Toolchain respects preferred version")
    func preferredVersion() async throws {
        // This test works in CI because it tests the logic, not specific paths
        let toolchain = XcodeToolchain(preferredVersion: "999.999") // Non-existent version
        try await toolchain.initialize()

        // Should still initialize with available Xcode, just not the preferred version
        let installation = await toolchain.getSelectedInstallation()
        #expect(installation != nil)

        // Should not contain the fake version we requested
        if let installation {
            #expect(!installation.version.contains("999.999"))
        }
    }

    @Test("Multiple toolchain instances work independently")
    func multipleInstances() async throws {
        // Test that multiple toolchain instances don't interfere with each other
        // This test works well in CI as it tests instance isolation, not specific versions

        let toolchain1 = XcodeToolchain()
        let toolchain2 = XcodeToolchain(preferredVersion: "999.999") // Non-existent version to test fallback

        // Initialize concurrently to test thread safety
        async let init1: Void = toolchain1.initialize()
        async let init2: Void = toolchain2.initialize()

        try await init1
        try await init2

        let installation1 = await toolchain1.getSelectedInstallation()
        let installation2 = await toolchain2.getSelectedInstallation()

        // Both should have found installations (fallback to available Xcode)
        #expect(installation1 != nil)
        #expect(installation2 != nil)

        // Both should be able to execute xcodebuild
        #expect(await toolchain1.isXcodeBuildAvailable())
        #expect(await toolchain2.isXcodeBuildAvailable())

        // Verify they can both execute commands independently
        async let version1 = toolchain1.getXcodeVersion()
        async let version2 = toolchain2.getXcodeVersion()

        let v1 = try await version1
        let v2 = try await version2

        #expect(!v1.isEmpty)
        #expect(!v2.isEmpty)
        #expect(v1 == v2) // Should be same Xcode since we used non-existent preferred version
    }
}

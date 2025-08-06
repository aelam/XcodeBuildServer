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
        // Test with a custom developer directory
        let customDir = "/Applications/Xcode.app/Contents/Developer"

        if FileManager.default.fileExists(atPath: customDir) {
            let toolchain = XcodeToolchain(customDeveloperDir: customDir)
            try await toolchain.initialize()

            let installation = await toolchain.getSelectedInstallation()
            #expect(installation != nil)
            #expect(installation?.isDeveloperDirSet == true)
        }
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
}

//
//  XcodeSchemeLoaderTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeSchemeParser

struct XcodeSchemeLoaderTests {
    private let schemeLoader = XcodeSchemeLoader()

    // Sample test schemes
    private let testSchemes: [XcodeSchemeInfo] = [
        XcodeSchemeInfo(
            name: "App",
            configuration: "Debug",
            buildableTargets: [
                XcodeSchemeTargetInfo(
                    targetName: "MyApp",
                    blueprintIdentifier: "APP123",
                    buildForTesting: true,
                    buildForRunning: true,
                    buildForProfiling: true,
                    buildForArchiving: true,
                    buildForAnalyzing: true
                ),
                XcodeSchemeTargetInfo(
                    targetName: "MyAppTests",
                    blueprintIdentifier: "TEST123",
                    buildForTesting: true,
                    buildForRunning: false,
                    buildForProfiling: false,
                    buildForArchiving: false,
                    buildForAnalyzing: false
                )
            ],
            testableTargets: [
                XcodeSchemeTargetInfo(
                    targetName: "MyAppTests",
                    blueprintIdentifier: "TEST123",
                    buildForTesting: true,
                    buildForRunning: false,
                    buildForProfiling: false,
                    buildForArchiving: false,
                    buildForAnalyzing: false
                )
            ]
        ),
        XcodeSchemeInfo(
            name: "UITests",
            configuration: "Debug",
            buildableTargets: [
                XcodeSchemeTargetInfo(
                    targetName: "MyApp",
                    blueprintIdentifier: "APP123",
                    buildForTesting: false,
                    buildForRunning: true,
                    buildForProfiling: false,
                    buildForArchiving: false,
                    buildForAnalyzing: false
                ),
                XcodeSchemeTargetInfo(
                    targetName: "MyAppUITests",
                    blueprintIdentifier: "UI123",
                    buildForTesting: true,
                    buildForRunning: false,
                    buildForProfiling: false,
                    buildForArchiving: false,
                    buildForAnalyzing: false
                )
            ],
            testableTargets: [
                XcodeSchemeTargetInfo(
                    targetName: "MyAppUITests",
                    blueprintIdentifier: "UI123",
                    buildForTesting: true,
                    buildForRunning: false,
                    buildForProfiling: false,
                    buildForArchiving: false,
                    buildForAnalyzing: false
                )
            ]
        )
    ]

    @Test
    func getAnyAvailableScheme() throws {
        let schemeName = try schemeLoader.getAnyAvailableScheme(from: testSchemes)
        #expect(schemeName == "App") // First scheme
    }

    @Test
    func getAnyAvailableSchemeThrowsWhenEmpty() throws {
        #expect(throws: XcodeSchemeError.self) {
            try schemeLoader.getAnyAvailableScheme(from: [])
        }
    }

    @Test
    func getTargetFromScheme() throws {
        let targetName = try schemeLoader.getTargetFromScheme(schemeName: "App", in: testSchemes)
        #expect(targetName == "MyApp") // First buildable target (runnable > testable)
    }

    @Test
    func getTargetFromSchemeThrowsForInvalidScheme() throws {
        #expect(throws: XcodeSchemeError.self) {
            try schemeLoader.getTargetFromScheme(schemeName: "NonExistent", in: testSchemes)
        }
    }

    @Test
    func getSchemeByName() throws {
        let scheme = try schemeLoader.getScheme(named: "UITests", from: testSchemes)
        #expect(scheme.name == "UITests")
        #expect(scheme.targets.count == 2)
    }

    @Test
    func getSchemeByNameThrowsForInvalidName() throws {
        #expect(throws: XcodeSchemeError.self) {
            try schemeLoader.getScheme(named: "NonExistent", from: testSchemes)
        }
    }

    @Test
    func getAllRunnableTargets() throws {
        let runnableTargets = schemeLoader.getAllRunnableTargets(from: testSchemes)
        #expect(runnableTargets.count == 1)
        #expect(runnableTargets.contains("MyApp"))
    }

    @Test
    func getAllTestableTargets() throws {
        let testableTargets = schemeLoader.getAllTestableTargets(from: testSchemes)
        #expect(testableTargets.count == 2)
        #expect(testableTargets.contains("MyAppTests"))
        #expect(testableTargets.contains("MyAppUITests"))
    }

    @Test
    func getAllTargetNames() throws {
        let targets = schemeLoader.getAllTargetNames(from: testSchemes)
        #expect(targets.count == 3)
        #expect(targets.contains("MyApp"))
        #expect(targets.contains("MyAppTests"))
        #expect(targets.contains("MyAppUITests"))
    }

    @Test
    func getSchemesContainingTarget() throws {
        let schemesWithApp = schemeLoader.getSchemes(containing: "MyApp", from: testSchemes)
        #expect(schemesWithApp.count == 2) // Both schemes contain MyApp

        let schemesWithTests = schemeLoader.getSchemes(containing: "MyAppTests", from: testSchemes)
        #expect(schemesWithTests.count == 1) // Only App scheme contains MyAppTests
        #expect(schemesWithTests.first?.name == "App")

        let schemesWithNonExistent = schemeLoader.getSchemes(containing: "NonExistent", from: testSchemes)
        #expect(schemesWithNonExistent.isEmpty)
    }

    @Test
    func getPreferredSchemeForTarget() throws {
        // For MyApp, should prefer the scheme where it's runnable (App scheme)
        let preferredForApp = schemeLoader.getPreferredScheme(for: "MyApp", from: testSchemes)
        #expect(preferredForApp?.name == "App") // App scheme has MyApp as runnable

        // For test targets, should return the first scheme containing them
        let preferredForTest = schemeLoader.getPreferredScheme(for: "MyAppTests", from: testSchemes)
        #expect(preferredForTest?.name == "App")

        // For non-existent target, should return nil
        let preferredForNonExistent = schemeLoader.getPreferredScheme(for: "NonExistent", from: testSchemes)
        #expect(preferredForNonExistent == nil)
    }

    @Test
    func validateSchemesSuccess() throws {
        // Should not throw for valid schemes
        try schemeLoader.validateSchemes(testSchemes)
    }

    @Test
    func validateSchemesThrowsForEmptySchemes() throws {
        #expect(throws: XcodeSchemeError.self) {
            try schemeLoader.validateSchemes([])
        }
    }

    @Test
    func loadSchemesWithProjectReference() async throws {
        // Create a temporary workspace structure with schemes
        let workspaceDir = createTemporaryWorkspaceStructure()
        defer { try? FileManager.default.removeItem(at: workspaceDir) }

        // Test loading all schemes
        let allSchemes = try schemeLoader.loadSchemes(fromWorkspace: workspaceDir)
        #expect(allSchemes.count == 2) // App.xcscheme and Tests.xcscheme

        // Test loading with specific scheme filter
        let filteredSchemes = try schemeLoader.loadSchemes(fromWorkspace: workspaceDir, filterBy: ["App"])
        #expect(filteredSchemes.count == 1)
        #expect(filteredSchemes.first?.name == "App")
    }

    @Test
    func loadSchemesThrowsForInvalidSchemeFilter() async throws {
        let workspaceDir = createTemporaryWorkspaceStructure()
        defer { try? FileManager.default.removeItem(at: workspaceDir) }

        await #expect(throws: XcodeSchemeError.self) {
            try schemeLoader.loadSchemes(fromWorkspace: workspaceDir, filterBy: ["NonExistentScheme"])
        }
    }

    // MARK: - Helper Methods

    private func createTemporaryWorkspaceStructure() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let schemesDir = tempDir.appendingPathComponent("xcshareddata/xcschemes")

        do {
            try FileManager.default.createDirectory(at: schemesDir, withIntermediateDirectories: true)

            // Create test scheme files with valid XML content
            let appSchemeContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <Scheme version="1.3">
               <BuildAction>
                  <BuildActionEntries>
                     <BuildActionEntry buildForRunning="YES">
                        <BuildableReference BlueprintName="MyApp" BlueprintIdentifier="APP123"/>
                     </BuildActionEntry>
                  </BuildActionEntries>
               </BuildAction>
               <LaunchAction buildConfiguration="Debug"/>
            </Scheme>
            """

            let testsSchemeContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <Scheme version="1.3">
               <BuildAction>
                  <BuildActionEntries>
                     <BuildActionEntry buildForTesting="YES">
                        <BuildableReference BlueprintName="MyAppTests" BlueprintIdentifier="TEST123"/>
                     </BuildActionEntry>
                  </BuildActionEntries>
               </BuildAction>
               <LaunchAction buildConfiguration="Debug"/>
            </Scheme>
            """

            try appSchemeContent.write(
                to: schemesDir.appendingPathComponent("App.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
            try testsSchemeContent.write(
                to: schemesDir.appendingPathComponent("Tests.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fatalError("Failed to create temporary workspace structure: \(error)")
        }

        return tempDir
    }
}

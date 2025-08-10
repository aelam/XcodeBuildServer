//
//  XcodeSchemeParserTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeSchemeParser

// swiftlint:disable:next all
struct XcodeSchemeParserTests {
    private let parser = XcodeSchemeParser()

    // Test data for basic scheme
    private static let basicSchemeXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme
       LastUpgradeVersion = "1200"
       version = "1.3">
       <BuildAction
          parallelizeBuildables = "YES"
          buildImplicitDependencies = "YES">
          <BuildActionEntries>
             <BuildActionEntry
                buildForTesting = "YES"
                buildForRunning = "YES"
                buildForProfiling = "YES"
                buildForArchiving = "YES"
                buildForAnalyzing = "YES">
                <BuildableReference
                   BuildableIdentifier = "primary"
                   BlueprintIdentifier = "ABC123DEF456"
                   BuildableName = "TestApp.app"
                   BlueprintName = "TestApp"
                   ReferencedContainer = "container:TestApp.xcodeproj">
                </BuildableReference>
             </BuildActionEntry>
          </BuildActionEntries>
       </BuildAction>
       <TestAction
          buildConfiguration = "Debug"
          selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
          selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
          shouldUseLaunchSchemeArgsEnv = "YES">
       </TestAction>
       <LaunchAction
          buildConfiguration = "Debug"
          selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
          selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
          launchStyle = "0"
          useCustomWorkingDirectory = "NO"
          ignoresPersistentStateOnLaunch = "NO"
          debugDocumentVersioning = "YES"
          debugServiceExtension = "internal"
          allowLocationSimulation = "YES">
       </LaunchAction>
    </Scheme>
    """

    @Test(arguments: [("TestScheme", basicSchemeXML)])
    func parseBasicScheme(schemeName: String, schemeXML: String) throws {
        let tempURL = createTemporarySchemeFile(content: schemeXML, name: schemeName)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Test basic scheme info
        #expect(schemeInfo.name == schemeName)
        #expect(schemeInfo.configuration == "Debug")
        #expect(schemeInfo.buildableTargets.count == 1)

        // Test target info
        let target = try #require(schemeInfo.buildableTargets.first)
        #expect(target.targetName == "TestApp")
        #expect(target.blueprintIdentifier == "ABC123DEF456")
        #expect(target.buildForTesting == true)
        #expect(target.buildForRunning == true)
        #expect(target.buildForProfiling == true)
        #expect(target.buildForArchiving == true)
        #expect(target.buildForAnalyzing == true)

        // Test helper properties
        #expect(schemeInfo.testTargets.isEmpty)
        #expect(schemeInfo.runTargets.count == 1)
        #expect(schemeInfo.firstBuildableTarget?.targetName == "TestApp")
    }

    // Test data for multiple targets scheme
    private static let multipleTargetsXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme version = "1.3">
       <BuildAction>
          <BuildActionEntries>
             <BuildActionEntry
                buildForTesting = "NO"
                buildForRunning = "YES"
                buildForProfiling = "YES"
                buildForArchiving = "YES"
                buildForAnalyzing = "YES">
                <BuildableReference
                   BlueprintIdentifier = "APP123"
                   BlueprintName = "MyApp">
                </BuildableReference>
             </BuildActionEntry>
             <BuildActionEntry
                buildForTesting = "YES"
                buildForRunning = "NO"
                buildForProfiling = "NO"
                buildForArchiving = "NO"
                buildForAnalyzing = "NO">
                <BuildableReference
                   BlueprintIdentifier = "TEST456"
                   BlueprintName = "MyAppTests">
                </BuildableReference>
             </BuildActionEntry>
             <BuildActionEntry
                buildForTesting = "YES"
                buildForRunning = "NO"
                buildForProfiling = "NO"
                buildForArchiving = "NO"
                buildForAnalyzing = "NO">
                <BuildableReference
                   BlueprintIdentifier = "UI789"
                   BlueprintName = "MyAppUITests">
                </BuildableReference>
             </BuildActionEntry>
          </BuildActionEntries>
       </BuildAction>
       <LaunchAction buildConfiguration = "Release">
       </LaunchAction>
    </Scheme>
    """

    @Test(arguments: [("MultiTarget", multipleTargetsXML)])
    func parseMultipleTargetsScheme(schemeName: String, schemeXML: String) throws {
        let tempURL = createTemporarySchemeFile(content: schemeXML, name: schemeName)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Test scheme with multiple targets
        #expect(schemeInfo.name == schemeName)
        #expect(schemeInfo.configuration == "Release")
        #expect(schemeInfo.targets.count == 3)

        // Test app target
        let appTarget = try #require(schemeInfo.targets.first { $0.targetName == "MyApp" })
        #expect(appTarget.buildForTesting == false)
        #expect(appTarget.buildForRunning == true)
        #expect(appTarget.buildForProfiling == true)

        // Test test targets
        let testTarget = try #require(schemeInfo.targets.first { $0.targetName == "MyAppTests" })
        #expect(testTarget.buildForTesting == true)
        #expect(testTarget.buildForRunning == false)

        let uiTestTarget = try #require(schemeInfo.targets.first { $0.targetName == "MyAppUITests" })
        #expect(uiTestTarget.buildForTesting == true)
        #expect(uiTestTarget.buildForRunning == false)

        // Test helper properties
        #expect(schemeInfo.testTargets.count == 2) // MyAppTests + MyAppUITests
        #expect(schemeInfo.runTargets.count == 1) // MyApp only
        #expect(schemeInfo.firstBuildableTarget?.targetName == "MyApp") // Should prefer runnable
    }

    // Test data for different configuration sources
    private static let configTestXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme version = "1.3">
       <BuildAction>
          <BuildActionEntries>
             <BuildActionEntry
                buildForTesting = "YES"
                buildForRunning = "YES">
                <BuildableReference
                   BlueprintIdentifier = "ABC123"
                   BlueprintName = "TestApp">
                </BuildableReference>
             </BuildActionEntry>
          </BuildActionEntries>
       </BuildAction>
       <TestAction buildConfiguration = "Debug">
       </TestAction>
       <ProfileAction buildConfiguration = "Release">
       </ProfileAction>
    </Scheme>
    """

    @Test(arguments: [("ConfigTest", configTestXML)])
    func parseSchemeWithDifferentConfigurationSources(schemeName: String, schemeXML: String) throws {
        let tempURL = createTemporarySchemeFile(content: schemeXML, name: schemeName)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Should prefer TestAction over ProfileAction
        #expect(schemeInfo.configuration == "Debug")
    }

    // MARK: - Helper Methods

    private func createTemporarySchemeFile(content: String, name: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let schemeURL = tempDir.appendingPathComponent("\(name).xcscheme")

        do {
            try content.write(to: schemeURL, atomically: true, encoding: .utf8)
        } catch {
            fatalError("Failed to create temporary scheme file: \(error)")
        }

        return schemeURL
    }
}

//
//  XcodeSchemeParserTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeSchemeParser

struct XcodeSchemeParserTests {
    private let parser = XcodeSchemeParser()

    @Test
    func parseBasicScheme() throws {
        let schemeXML = """
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

        let tempURL = createTemporarySchemeFile(content: schemeXML, name: "TestScheme")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Test basic scheme info
        #expect(schemeInfo.name == "TestScheme")
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

    @Test
    func parseMultipleTargetsScheme() throws {
        let schemeXML = """
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

        let tempURL = createTemporarySchemeFile(content: schemeXML, name: "MultiTarget")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Test scheme with multiple targets
        #expect(schemeInfo.name == "MultiTarget")
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

    @Test
    func parseSchemeWithDifferentConfigurationSources() throws {
        let schemeXML = """
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

        let tempURL = createTemporarySchemeFile(content: schemeXML, name: "ConfigTest")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Should prefer TestAction over ProfileAction
        #expect(schemeInfo.configuration == "Debug")
    }

    @Test
    func parseSchemeWithLaunchActionConfiguration() throws {
        let schemeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme version = "1.3">
           <BuildAction>
              <BuildActionEntries>
                 <BuildActionEntry buildForRunning = "YES">
                    <BuildableReference
                       BlueprintIdentifier = "ABC123"
                       BlueprintName = "TestApp">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <LaunchAction buildConfiguration = "Custom">
           </LaunchAction>
           <TestAction buildConfiguration = "Debug">
           </TestAction>
        </Scheme>
        """

        let tempURL = createTemporarySchemeFile(content: schemeXML, name: "LaunchConfig")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Should prefer LaunchAction configuration
        #expect(schemeInfo.configuration == "Custom")
    }

    @Test
    func parseEmptyScheme() throws {
        let schemeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme version = "1.3">
        </Scheme>
        """

        let tempURL = createTemporarySchemeFile(content: schemeXML, name: "EmptyScheme")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        #expect(schemeInfo.name == "EmptyScheme")
        #expect(schemeInfo.configuration == nil)
        #expect(schemeInfo.targets.isEmpty)
        #expect(schemeInfo.testTargets.isEmpty)
        #expect(schemeInfo.runTargets.isEmpty)
        #expect(schemeInfo.firstBuildableTarget == nil)
    }

    @Test
    func parseInvalidScheme() throws {
        let invalidXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <InvalidRoot>
        </InvalidRoot>
        """

        let tempURL = createTemporarySchemeFile(content: invalidXML, name: "Invalid")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: XcodeSchemeError.self) {
            try parser.parseScheme(at: tempURL)
        }
    }

    @Test
    func parseRealSchemeContent() throws {
        // Create a complete scheme with TestAction that has Testables
        let realSchemeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme
           LastUpgradeVersion = "1430"
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
                       BlueprintIdentifier = "E2B4C7A92A8F123456789ABC"
                       BuildableName = "XcodeBuildServer"
                       BlueprintName = "XcodeBuildServer"
                       ReferencedContainer = "container:XcodeBuildServer.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
                 <BuildActionEntry
                    buildForTesting = "YES"
                    buildForRunning = "NO"
                    buildForProfiling = "NO"
                    buildForArchiving = "NO"
                    buildForAnalyzing = "NO">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "F3C5D8B43B9F234567890DEF"
                       BuildableName = "XcodeBuildServerTests.xctest"
                       BlueprintName = "XcodeBuildServerTests"
                       ReferencedContainer = "container:XcodeBuildServer.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES">
              <Testables>
                 <TestableReference
                    skipped = "NO">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "F3C5D8B43B9F234567890DEF"
                       BuildableName = "XcodeBuildServerTests.xctest"
                       BlueprintName = "XcodeBuildServerTests"
                       ReferencedContainer = "container:XcodeBuildServer.xcodeproj">
                    </BuildableReference>
                 </TestableReference>
              </Testables>
           </TestAction>
           <LaunchAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB">
           </LaunchAction>
        </Scheme>
        """

        let tempURL = createTemporarySchemeFile(content: realSchemeXML, name: "TestScheme")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Test the real scheme file parsing
        #expect(schemeInfo.name == "TestScheme")
        #expect(schemeInfo.configuration == "Debug") // LaunchAction configuration

        // Test buildable targets (from BuildAction)
        #expect(schemeInfo.buildableTargets.count == 2)
        #expect(schemeInfo.targets.count == 2) // Legacy property should work

        // Test main buildable target
        let mainTarget = try #require(schemeInfo.buildableTargets.first { $0.targetName == "XcodeBuildServer" })
        #expect(mainTarget.blueprintIdentifier == "E2B4C7A92A8F123456789ABC")
        #expect(mainTarget.buildForTesting == true)
        #expect(mainTarget.buildForRunning == true)
        #expect(mainTarget.buildForProfiling == true)
        #expect(mainTarget.buildForArchiving == true)
        #expect(mainTarget.buildForAnalyzing == true)

        // Test test buildable target
        let testTarget = try #require(schemeInfo.buildableTargets.first { $0.targetName == "XcodeBuildServerTests" })
        #expect(testTarget.blueprintIdentifier == "F3C5D8B43B9F234567890DEF")
        #expect(testTarget.buildForTesting == true)
        #expect(testTarget.buildForRunning == false)
        #expect(testTarget.buildForProfiling == false)
        #expect(testTarget.buildForArchiving == false)
        #expect(testTarget.buildForAnalyzing == false)

        // Test testable targets (from TestAction) - should include only actual test target
        #expect(schemeInfo.testableTargets.count == 1)
        let testableTarget = try #require(schemeInfo.testableTargets.first)
        #expect(testableTarget.targetName == "XcodeBuildServerTests")
        #expect(testableTarget.buildForTesting == true) // TestableReference implies testing

        // Test helper properties
        #expect(schemeInfo.testTargets.count == 1) // Only actual testable targets
        #expect(schemeInfo.runTargets.count == 1) // Only main target runs
        #expect(schemeInfo.firstBuildableTarget?.targetName == "XcodeBuildServer")
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

    private func createTemporaryWorkspaceStructure() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let schemesDir = tempDir.appendingPathComponent("xcshareddata/xcschemes")

        do {
            try FileManager.default.createDirectory(at: schemesDir, withIntermediateDirectories: true)

            // Create some test scheme files
            try "scheme content".write(
                to: schemesDir.appendingPathComponent("App.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
            try "scheme content".write(
                to: schemesDir.appendingPathComponent("Tests.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fatalError("Failed to create temporary workspace structure: \(error)")
        }

        return tempDir
    }

    private func createTemporaryProjectStructure() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let schemesDir = tempDir.appendingPathComponent("xcshareddata/xcschemes")

        do {
            try FileManager.default.createDirectory(at: schemesDir, withIntermediateDirectories: true)

            // Create a test scheme file
            try "scheme content".write(
                to: schemesDir.appendingPathComponent("MyProject.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fatalError("Failed to create temporary project structure: \(error)")
        }

        return tempDir
    }

    private func createTemporaryWorkspaceWithUserSchemes() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sharedSchemesDir = tempDir.appendingPathComponent("xcshareddata/xcschemes")
        let userSchemesDir = tempDir.appendingPathComponent("xcuserdata/testuser.xcuserdatad/xcschemes")

        do {
            try FileManager.default.createDirectory(at: sharedSchemesDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: userSchemesDir, withIntermediateDirectories: true)

            // Create shared schemes
            try "scheme content".write(
                to: sharedSchemesDir.appendingPathComponent("App.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
            try "scheme content".write(
                to: sharedSchemesDir.appendingPathComponent("Tests.xcscheme"),
                atomically: true,
                encoding: .utf8
            )

            // Create user scheme
            try "scheme content".write(
                to: userSchemesDir.appendingPathComponent("UserScheme.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fatalError("Failed to create temporary workspace with user schemes: \(error)")
        }

        return tempDir
    }
}

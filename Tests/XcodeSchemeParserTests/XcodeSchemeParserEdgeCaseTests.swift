//
//  XcodeSchemeParserEdgeCaseTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeSchemeParser

/// Edge case tests for XcodeSchemeParser
struct XcodeSchemeParserEdgeCaseTests {
    private let parser = XcodeSchemeParser()

    // Test data for launch action configuration
    private static let launchConfigXML = """
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

    @Test(arguments: [("LaunchConfig", launchConfigXML)])
    func parseSchemeWithLaunchActionConfiguration(schemeName: String, schemeXML: String) throws {
        let tempURL = createTemporarySchemeFile(content: schemeXML, name: schemeName)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        // Should prefer LaunchAction configuration
        #expect(schemeInfo.configuration == "Custom")
    }

    // Test data for empty scheme
    private static let emptySchemeXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme version = "1.3">
    </Scheme>
    """

    @Test(arguments: [("EmptyScheme", emptySchemeXML)])
    func parseEmptyScheme(schemeName: String, schemeXML: String) throws {
        let tempURL = createTemporarySchemeFile(content: schemeXML, name: schemeName)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let schemeInfo = try parser.parseScheme(at: tempURL)

        #expect(schemeInfo.name == schemeName)
        #expect(schemeInfo.configuration == nil)
        #expect(schemeInfo.targets.isEmpty)
        #expect(schemeInfo.testTargets.isEmpty)
        #expect(schemeInfo.runTargets.isEmpty)
        #expect(schemeInfo.firstBuildableTarget == nil)
    }

    // Test data for invalid scheme
    private static let invalidXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <InvalidRoot>
    </InvalidRoot>
    """

    @Test(arguments: [("Invalid", invalidXML)])
    func parseInvalidScheme(schemeName: String, schemeXML: String) throws {
        let tempURL = createTemporarySchemeFile(content: schemeXML, name: schemeName)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: XcodeSchemeError.self) {
            try parser.parseScheme(at: tempURL)
        }
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

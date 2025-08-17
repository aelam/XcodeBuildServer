import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeBuildSettingsForIndexFixtureTests {
    @Test
    func fix() async throws {
        let indexFile = Bundle.module.resourceURL!
            .appendingPathComponent("buildSettingsForIndexForTarget.json")
        let data = try Data(contentsOf: indexFile)
        let jsonDecoder = JSONDecoder()
        let buildSettingsForIndex = try jsonDecoder.decode(XcodeBuildSettingsForIndex.self, from: data)

        let projectSettings = IndexFixture.ProjectBuildSettings(
            projectName: "__TestProject__",
            target: "__TestTarget__",
            configuration: "Debug",
            sdk: "iphonesimulator",
            derivedDataPath: "__derivedDataPath__"
        )

        let fixedBuildSettingsForIndex = IndexFixture.fix(
            buildSettingsForIndex: buildSettingsForIndex,
            projectBuildSettings: projectSettings
        )

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let jsonData = try jsonEncoder.encode(fixedBuildSettingsForIndex)
        let jsonString = String(data: jsonData, encoding: .utf8)
        print(jsonString ?? "")
    }
}

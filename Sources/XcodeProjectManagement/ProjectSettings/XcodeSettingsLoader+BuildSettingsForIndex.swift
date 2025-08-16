import Foundation
import Logger

extension XcodeSettingsLoader {
    // MARK: - BuildSettingsForIndex

    /// Load buildSettingsForIndex for source file discovery
    public func loadBuildSettingsForIndex(
        rootURL: URL,
        targets: [XcodeTarget],
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        try await withThrowingTaskGroup(of: XcodeBuildSettingsForIndex.self) { taskGroup in
            // group targets under same project
            let groupedTargets = Dictionary(grouping: targets) { $0.projectURL }

            for (projectURL, targets) in groupedTargets {
                taskGroup.addTask {
                    let buildSettingForProject = try await self.loadBuildSettingsForIndex(
                        rootURL: rootURL,
                        projectURL: projectURL,
                        targets: targets.map(\.name),
                        derivedDataPath: derivedDataPath
                    )
                    var targetBuildSettings: XcodeBuildSettingsForIndex = [:]
                    for (targetName, settings) in buildSettingForProject {
                        let targetIdentifier = "xcode://" + projectURL.appendingPathComponent(targetName).path
                        targetBuildSettings[targetIdentifier] = settings
                    }
                    return targetBuildSettings
                }
            }

            var buildSettings: XcodeBuildSettingsForIndex = [:]
            for try await targetSettings in taskGroup {
                buildSettings.merge(targetSettings) { _, new in new }
            }
            return buildSettings
        }
    }

    /// Load build settings for index for all targets in same project
    /// it would perform much faster than loading settings for each target individually
    private func loadBuildSettingsForIndex(
        rootURL: URL,
        projectURL: URL, // xcodeproj file URL
        targets: [String] = [],
        derivedDataPath: URL
    ) async throws -> XcodeBuildSettingsForIndex {
        let command = commandBuilder.buildCommand(
            project: .project(
                projectURL: projectURL,
                buildMode: .targets(targets),
                configuration: nil
            ),
            options: XcodeBuildOptions.buildSettingsForIndexJSON(derivedDataPath: derivedDataPath.path)
        )

        let output = try await runXcodeBuild(arguments: command, workingDirectory: rootURL)
        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings for index")
        }

        let data = Data(jsonString.utf8)
        do {
            return try jsonDecoder.decode(XcodeBuildSettingsForIndex.self, from: data)
        } catch {
            throw XcodeProjectError.invalidConfig("Failed to decode build settings for index: \(error)")
        }
    }
}

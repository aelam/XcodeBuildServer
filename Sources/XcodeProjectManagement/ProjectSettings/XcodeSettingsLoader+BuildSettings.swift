import Foundation
import Logger

public extension XcodeSettingsLoader {
    // MARK: - BuildSettings

    func loadBuildSettings(
        rootURL: URL,
        project: XcodeProjectConfiguration,
    ) async throws -> [XcodeBuildSettings] {
        let command = commandBuilder.buildCommand(
            project: project,
            options: XcodeBuildOptions.buildSettingsJSON()
        )
        let output = try await runXcodeBuild(arguments: command, workingDirectory: rootURL)
        guard let jsonString = output, !jsonString.isEmpty else {
            throw XcodeProjectError.invalidConfig("Failed to load build settings")
        }

        let data = Data(jsonString.utf8)
        do {
            return try jsonDecoder.decode([XcodeBuildSettings].self, from: data)
        } catch {
            logger.debug(jsonString)
            throw XcodeProjectError.invalidConfig("Failed to decode build settings: \(error)")
        }
    }
}

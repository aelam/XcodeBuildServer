import Foundation
import Logger

extension XcodeProjectManager {
    /// Get schemes from workspace using xcodebuild -list
    func getWorkspaceSchemes(projectLocation: XcodeProjectLocation) async throws -> [String] {
        guard case let .explicitWorkspace(workspaceURL) = projectLocation else {
            return []
        }

        // Create a temporary settings loader just for listing schemes
        let commandBuilder = XcodeBuildCommandBuilder()
        // Use xcodebuild -list to get schemes
        let command = commandBuilder.listSchemesCommand(
            project: XcodeProjectConfiguration.workspace(
                workspaceURL: workspaceURL,
                scheme: nil
            )
        )

        let output = try await settingsLoader.runXcodeBuild(arguments: command, workingDirectory: workspaceURL)

        guard let jsonString = output, !jsonString.isEmpty else {
            logger.warning("Failed to get schemes from workspace \(workspaceURL.path)")
            return []
        }

        // Parse the JSON to extract schemes
        let data = Data(jsonString.utf8)
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let workspace = json["workspace"] as? [String: Any],
               let schemes = workspace["schemes"] as? [String] {
                logger.debug("Found schemes for workspace: \(schemes)")
                return schemes
            } else {
                logger.warning("Unexpected JSON format when listing schemes")
                return []
            }
        } catch {
            logger.error("Failed to parse schemes JSON: \(error)")
            return []
        }
    }
}

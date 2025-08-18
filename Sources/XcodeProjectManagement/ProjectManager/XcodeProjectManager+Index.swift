import Foundation

public extension XcodeProjectManager {
    func buildTargetForIndex(
        _ target: String,
        projectInfo: XcodeProjectInfo,
    ) async throws -> XcodeBuildResult {
        let targetIdentifier = TargetIdentifier(rawValue: target)
        let projectPath = targetIdentifier.projectFilePath
        let targetName = targetIdentifier.targetName

        // Build Target

        let options = XcodeBuildOptions(
            command: .build(
                action: .build,
                sdk: .iOSSimulator,
                destination: nil,
                configuration: projectInfo.primaryBuildSettings.configuration,
                derivedDataPath: nil,
                resultBundlePath: nil
            ),
            flags: XcodeBuildFlags(),
            customFlags: [
                "SYMROOT=" + projectInfo.primaryBuildSettings.derivedDataPath.appendingPathComponent("Build/Products")
                    .path,
                "OBJROOT=" + projectInfo.primaryBuildSettings.derivedDataPath
                    .appendingPathComponent("Build/Intermediates.noindex")
                    .path,
                "SDK_STAT_CACHE_DIR=" + projectInfo.primaryBuildSettings.derivedDataPath.deletingLastPathComponent()
                    .path,
            ]
        )

        let commandBuilder = XcodeBuildCommandBuilder()
        let command = commandBuilder.buildCommand(
            project: .project(
                projectURL: URL(filePath: projectPath),
                buildMode: .targets([targetName])
            ),
            options: options
        )

        let result = try await toolchain.executeXcodeBuild(
            arguments: command,
            workingDirectory: projectInfo.rootURL
        )
        return result
    }
}

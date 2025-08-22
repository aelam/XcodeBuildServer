import Core
import Foundation
import Logger
import XcodeProjectManagement

extension XcodeProjectManager: @preconcurrency ProjectManager {
    public func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget] {
        projectInfo?.targets ?? []
    }

    public func getSourceFileList(targetIdentifier: String) async -> [URL] {
        guard let xcodeProjectInfo else {
            return []
        }

        logger.debug("\(targetIdentifier)")
        guard let buildSettingsForIndex = xcodeProjectInfo.xcodeBuildSettingsForIndex[targetIdentifier] else {
            return []
        }

        logger.debug("\(buildSettingsForIndex.keys.map { URL(fileURLWithPath: $0) }.compactMap(\.self))")

        return buildSettingsForIndex.keys.map { URL(fileURLWithPath: $0) }.compactMap(\.self)
    }

    public var projectType: String {
        "xcodeproj"
    }

    public func buildGraph() async {}

    public func buildIndex(for targets: [String]) async {}

    public func startBuild(targets: [String]) async {}

    public var projectInfo: ProjectInfo? {
        xcodeProjectInfo?.asProjectInfo()
    }

    public func resolveProjectInfo() async throws -> ProjectInfo {
        let xcodeProjectInfo = try await resolveXcodeProjectInfo()
        return xcodeProjectInfo.asProjectInfo()
    }

    public func getCompileArguments(targetIdentifier: String, sourceFileURL: URL) async throws -> [String] {
        guard
            let xcodeProjectInfo,
            let language = Language(inferredFromFileExtension: sourceFileURL)
        else { return [] }
        let buildSettings = xcodeProjectInfo.xcodeBuildSettingsForIndex
        let buildSettingsForTarget = buildSettings[targetIdentifier]
        let buildSettingForFile = buildSettingsForTarget?[sourceFileURL.path]

        guard let buildSettingForFile else {
            return []
        }

        if language.isSwift {
            return buildSettingForFile.swiftASTCommandArguments ?? []
        } else if language.isClang {
            return buildSettingForFile.clangASTCommandArguments ?? []
        }
        return []
    }
}

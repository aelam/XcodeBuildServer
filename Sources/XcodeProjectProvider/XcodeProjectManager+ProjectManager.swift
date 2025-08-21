import Core
import Foundation
import XcodeProjectManagement

extension XcodeProjectManager: @preconcurrency ProjectManager {
    public func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget] {
        projectInfo?.targets ?? []
    }

    public func getSourceFileList(targetIdentifier: String) async -> [URL] {
        []
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

    public func getCompileArguments(targetIdentifier: String, sourceFileURL: String) async throws -> [String] {
        []
    }
}

import BuildServerProtocol
import Foundation
import Logger
import XcodeProjectManagement

extension XcodeProjectManager: @preconcurrency ProjectManager {
    public func getProjectState() async -> BuildServerProtocol.ProjectState {
        .init()
    }

    public func addStateObserver(_ observer: any BuildServerProtocol.ProjectStateObserver) async {}

    public func removeStateObserver(_ observer: any BuildServerProtocol.ProjectStateObserver) async {}

    public var projectType: String {
        "xcodeproj"
    }

    public func updateBuildGraph() async {}

    public func buildIndex(for targets: [BSPBuildTargetIdentifier]) async {
        // TODO: await startBuild(targetIdentifiers: targets)
    }

    public func startBuild(targetIdentifiers: [BSPBuildTargetIdentifier]) async throws -> BSPStatusCode {
        var results: [XcodeBuildResult] = []
        for identifier in targetIdentifiers {
            let xcodeTargetIdentifier = XcodeTargetIdentifier(rawValue: identifier.uri.stringValue)
            let xcodeBuildResult = try await compileTarget(targetIdentifier: xcodeTargetIdentifier)
            results.append(xcodeBuildResult)
        }

        for result in results where result.exitCode != 0 {
            logger.error("Build failed with exit code \(result.exitCode)")
            if let errorOutput = result.error, !errorOutput.isEmpty {
                logger.error("Build failed: \(errorOutput)")
            }
            return .error
        }

        return .ok
    }

    public var projectInfo: ProjectInfo? {
        xcodeProjectBaseInfo?.asProjectInfo()
    }

    public func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget] {
        projectInfo?.targets ?? []
    }

    public func getSourceFileList(targetIdentifiers: [BSPBuildTargetIdentifier]) async throws
        -> [BuildServerProtocol.SourcesItem] {
        let xcodeTargetIdentifiers = targetIdentifiers.map { identifier in
            XcodeTargetIdentifier(rawValue: identifier.uri.stringValue)
        }
        let xcodeSourceItems = getSourcesItems(targetIdentifiers: xcodeTargetIdentifiers)
        return try xcodeSourceItems.compactMap {
            try $0.asBSPSourcesItems()
        }
    }

    public func getCompileArguments(targetIdentifier: String, sourceFileURL: URL) async throws -> [String] {
        let xcodeTargetIdentifier = XcodeTargetIdentifier(rawValue: targetIdentifier)
        return try await getCompileArguments(targetIdentifier: xcodeTargetIdentifier, sourceFileURL: sourceFileURL)
    }
}

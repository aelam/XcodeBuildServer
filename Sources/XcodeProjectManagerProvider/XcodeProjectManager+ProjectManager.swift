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

    public func buildIndex(for targets: [String]) async {
        await startBuild(targets: targets)
    }

    public func startBuild(targets: [String]) async {}

    public var projectInfo: ProjectInfo? {
        xcodeProjectBaseInfo?.asProjectInfo()
    }

    public func getTargetList(
        resolveSourceFiles: Bool,
        resolveDependencies: Bool
    ) async -> [ProjectTarget] {
        projectInfo?.targets ?? []
    }

    public func getSourceFileList(targetIdentifiers: [BSPBuildTargetIdentifier]) async
        -> [BuildServerProtocol.SourcesItem] {
        let xcodeTargetIdentifiers = targetIdentifiers.map { identifier in
            TargetIdentifier(rawValue: identifier.uri.stringValue)
        }
        let xcodeSourceItems = getSourcesItems(targetIdentifiers: xcodeTargetIdentifiers)
        return xcodeSourceItems.map {
            $0.asBSPSourcesItems()
        }
    }

    public func getCompileArguments(targetIdentifier: String, sourceFileURL: URL) async throws -> [String] {
        let xcodeTargetIdentifier = TargetIdentifier(rawValue: targetIdentifier)
        return try await getCompileArguments(targetIdentifier: xcodeTargetIdentifier, sourceFileURL: sourceFileURL)
    }
}

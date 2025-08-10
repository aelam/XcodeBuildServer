//
//  BuiltTargetSourcesRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

/// Example request:
/// ```json
/// {
///   "params": {
///     "targets": [
///       {"uri": "xcode:///Hello.xcodeproj/Hello/Hello"},
///       {"uri": "xcode:///Hello.xcodeproj/Hello/HelloTests"},
///       {"uri": "xcode:///Hello.xcodeproj/Hello/HelloUITests"},
///       {"uri": "xcode:///Hello.xcodeproj/Hello/World"}
///     ]
///   },
///   "jsonrpc": "2.0",
///   "method": "buildTarget/sources",
///   "id": 3
/// }
/// ```

import Foundation
import XcodeProjectManagement

struct BuiltTargetSourcesRequest: ContextualRequestType, Sendable {
    typealias RequiredContext = BuildServerContext

    static func method() -> String {
        "buildTarget/sources"
    }

    struct Params: Codable, Sendable {
        let targets: [BuildTargetIdentifier]
    }

    let params: Params

    func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await contextualHandler.withContext { context in
            await handleBuildTargetSources(context: context, targetIds: params.targets)
        }
    }

    private func handleBuildTargetSources(
        context: BuildServerContext,
        targetIds: [BuildTargetIdentifier]
    ) async -> BuildTargetSourcesResponse {
        let sourceDiscovery = XcodeSourceFileDiscovery()
        var items: [SourcesItem] = []

        for targetId in targetIds {
            let sourcesItem = await buildSourcesItem(
                for: targetId,
                context: context,
                sourceDiscovery: sourceDiscovery
            )
            items.append(sourcesItem)
        }

        return BuildTargetSourcesResponse(items: items)
    }

    private func buildSourcesItem(
        for targetId: BuildTargetIdentifier,
        context: BuildServerContext,
        sourceDiscovery: XcodeSourceFileDiscovery
    ) async -> SourcesItem {
        do {
            // Parse target identifier to get target information
            let targetInfo = try parseTargetIdentifier(targetId.uri.stringValue)

            // Get project info from context
            guard let projectInfo = try? await context.getProjectBasicInfo() else {
                return createEmptySourcesItem(for: targetId)
            }

            // Find the target in build settings and build sources
            if let xcodeTarget = projectInfo.buildSettingsList
                .first(where: { $0.target == targetInfo.targetName }) {
                return await buildSourcesItemWithTarget(
                    targetId: targetId,
                    xcodeTarget: xcodeTarget,
                    projectInfo: projectInfo,
                    sourceDiscovery: sourceDiscovery
                )
            } else {
                return createEmptySourcesItem(for: targetId)
            }
        } catch {
            return createEmptySourcesItem(for: targetId)
        }
    }

    private func buildSourcesItemWithTarget(
        targetId: BuildTargetIdentifier,
        xcodeTarget: XcodeBuildSettings,
        projectInfo: XcodeProjectInfo,
        sourceDiscovery: XcodeSourceFileDiscovery
    ) async -> SourcesItem {
        do {
            // Create target info from build settings
            let target = XcodeTargetInfo(
                name: xcodeTarget.target,
                productType: xcodeTarget.buildSettings["PRODUCT_TYPE"],
                buildSettings: xcodeTarget.buildSettings
            )

            // Discover source files for this target
            let discoveredFiles = try await sourceDiscovery.discoverSourceFiles(
                for: target,
                projectInfo: projectInfo
            )

            // Convert to SourceItem objects
            let sourceItems = convertToSourceItems(discoveredFiles)

            // Get source roots
            let sourceRootURLs = sourceDiscovery.getSourceRoots(
                for: target,
                projectInfo: projectInfo
            )
            let sourceRoots = sourceRootURLs.compactMap { try? URI(string: $0.absoluteString) }

            return SourcesItem(
                target: targetId,
                sources: sourceItems,
                roots: sourceRoots
            )
        } catch {
            return createEmptySourcesItem(for: targetId)
        }
    }

    private func convertToSourceItems(_ discoveredFiles: [DiscoveredSourceFile]) -> [SourceItem] {
        discoveredFiles.compactMap { discoveredFile in
            let conversionResult = discoveredFile.toBSPFormat()

            guard let uri = try? URI(string: conversionResult.uri) else {
                return nil
            }

            // Create SourceKit data
            let sourceKitData = SourceKitSourceItemData(
                language: Language(rawValue: conversionResult.data?["language"] ?? ""),
                kind: SourceKitSourceItemKind(
                    rawValue: conversionResult.data?["kind"] ?? "source"
                ),
                outputPath: nil // TODO: Add output path from build settings if available
            )

            return SourceItem(
                uri: uri,
                kind: conversionResult.kind == 1 ? .file : .directory,
                generated: conversionResult.generated,
                dataKind: .sourceKit,
                data: sourceKitData.encodeToLSPAny()
            )
        }
    }

    private func createEmptySourcesItem(for targetId: BuildTargetIdentifier) -> SourcesItem {
        SourcesItem(target: targetId, sources: [], roots: nil)
    }

    /// Parse target identifier URI to extract target information
    private func parseTargetIdentifier(_ uri: String) throws -> TargetInfo {
        // Expected format: "xcode:///ProjectName/SchemeName/TargetName"
        guard let url = URL(string: uri) else {
            throw NSError(
                domain: "InvalidTargetURI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid target URI format"]
            )
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 3 else {
            let message = "Target URI must have format: xcode:///ProjectName/SchemeName/TargetName"
            throw NSError(
                domain: "InvalidTargetURI",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        return TargetInfo(
            projectName: pathComponents[0],
            schemeName: pathComponents[1],
            targetName: pathComponents[2]
        )
    }
}

/// Helper struct to hold parsed target information
private struct TargetInfo {
    let projectName: String
    let schemeName: String
    let targetName: String
}

public struct BuildTargetSourcesResponse: ResponseType, Hashable {
    public var items: [SourcesItem]

    public init(items: [SourcesItem]) {
        self.items = items
    }
}

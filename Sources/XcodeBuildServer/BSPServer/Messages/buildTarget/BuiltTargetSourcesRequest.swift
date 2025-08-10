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
        // Get source files from buildSettingsForIndex
        let sourceItems = await buildSourceItemsFromIndexSettings(
            targetName: xcodeTarget.target,
            projectInfo: projectInfo
        )

        // Get source roots from build settings
        let sourceRoots = extractSourceRoots(
            from: xcodeTarget.buildSettings,
            projectRoot: projectInfo.rootURL
        )

        return SourcesItem(
            target: targetId,
            sources: sourceItems,
            roots: sourceRoots
        )
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

// MARK: - Private Extension for Source Item Creation

private extension BuiltTargetSourcesRequest {
    func createEmptySourcesItem(for targetId: BuildTargetIdentifier) -> SourcesItem {
        SourcesItem(
            target: targetId,
            sources: [],
            roots: []
        )
    }

    func buildSourceItemsFromIndexSettings(
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) async -> [SourceItem] {
        guard let indexSettings = projectInfo.buildSettingsForIndex,
              let targetFiles = indexSettings[targetName] else {
            return []
        }

        var sourceItems: [SourceItem] = []

        for (filePath, fileInfo) in targetFiles {
            guard let sourceItem = createSourceItem(
                filePath: filePath,
                fileInfo: fileInfo,
                projectRoot: projectInfo.rootURL
            ) else {
                continue
            }
            sourceItems.append(sourceItem)
        }

        return sourceItems
    }

    func extractSourceRoots(
        from buildSettings: [String: String],
        projectRoot: URL
    ) -> [URI] {
        var roots: [URI] = []

        // Add SRCROOT if available
        if let srcRoot = buildSettings["SRCROOT"] {
            let srcRootURL = URL(fileURLWithPath: srcRoot, relativeTo: projectRoot)
            if let uri = try? URI(string: srcRootURL.absoluteString) {
                roots.append(uri)
            }
        }

        // Add PROJECT_DIR if different from SRCROOT
        if let projectDir = buildSettings["PROJECT_DIR"],
           projectDir != buildSettings["SRCROOT"] {
            let projectDirURL = URL(fileURLWithPath: projectDir, relativeTo: projectRoot)
            if let uri = try? URI(string: projectDirURL.absoluteString) {
                roots.append(uri)
            }
        }

        // If no specific roots found, use project root
        if roots.isEmpty {
            if let uri = try? URI(string: projectRoot.absoluteString) {
                roots.append(uri)
            }
        }

        return roots
    }

    func createSourceItem(
        filePath: String,
        fileInfo: XcodeFileBuildSettingInfo,
        projectRoot: URL
    ) -> SourceItem? {
        let fileURL: URL = if filePath.hasPrefix("/") {
            URL(fileURLWithPath: filePath)
        } else {
            projectRoot.appendingPathComponent(filePath)
        }

        guard let uri = try? URI(string: fileURL.absoluteString) else {
            return nil
        }

        // Determine if the file is generated
        let generated = filePath.contains("DerivedData") ||
            filePath.contains("Build/") ||
            filePath.hasSuffix(".generated.swift")

        // Determine language based on file type
        let language: Language? = switch fileInfo.languageDialect {
        case .swift:
            .swift
        case .objc:
            .objective_c
        case .interfaceBuilder:
            nil // Interface Builder files might not have a specific BSP language
        case .other:
            detectLanguageFromExtension(fileURL.pathExtension)
        }

        // Create SourceKitSourceItemData
        let sourceKitData = SourceKitSourceItemData(
            language: language,
            kind: determineSourceKind(fileURL: fileURL, generated: generated),
            outputPath: fileInfo.outputFilePath
        )

        return SourceItem(
            uri: uri,
            kind: .file,
            generated: generated,
            dataKind: .sourceKit,
            data: sourceKitData.encodeToLSPAny()
        )
    }

    func detectLanguageFromExtension(_ ext: String) -> Language? {
        switch ext.lowercased() {
        case "swift":
            .swift
        case "c":
            .c
        case "cpp", "cc", "cxx", "c++":
            .cpp
        case "m":
            .objective_c
        case "mm":
            .objective_cpp
        case "h", "hpp", "hxx", "h++":
            .c // Could be C or C++, default to C
        default:
            nil
        }
    }

    func determineSourceKind(fileURL: URL, generated: Bool) -> SourceKitSourceItemKind {
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "h", "hpp", "hxx", "h++":
            return .header
        case "swift", "c", "cpp", "cc", "cxx", "c++", "m", "mm":
            return .source
        case "json", "plist", "xcassets":
            return .source
        default:
            return .source
        }
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

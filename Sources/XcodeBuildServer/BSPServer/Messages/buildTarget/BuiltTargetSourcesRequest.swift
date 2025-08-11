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
            await handleBuildTargetSources(context: context, targetIds: params.targets, requestId: id)
        }
    }

    private func handleBuildTargetSources(
        context: BuildServerContext,
        targetIds: [BuildTargetIdentifier],
        requestId: RequestID
    ) async -> BuildTargetSourcesResponse {
        var items: [SourcesItem] = []

        for targetId in targetIds {
            let sourcesItem = await buildSourcesItem(
                for: targetId,
                context: context
            )
            items.append(sourcesItem)
        }

        return BuildTargetSourcesResponse(id: requestId, items: items)
    }

    private func buildSourcesItem(
        for targetId: BuildTargetIdentifier,
        context: BuildServerContext
    ) async -> SourcesItem {
        do {
            // Parse target identifier to get target information
            let targetInfo = try parseTargetIdentifier(targetId.uri.stringValue)
            logger.debug("Parsed target info - projectName: \(targetInfo.projectName), " +
                "schemeName: \(targetInfo.schemeName), targetName: \(targetInfo.targetName)"
            )

            // Get project info from context
            guard let projectInfo = try? await context.getProjectBasicInfo() else {
                logger.error("Failed to get project info")
                return createEmptySourcesItem(for: targetId)
            }

            // Build sources directly from buildSettingsForIndex
            return await buildSourcesItemFromIndex(
                targetId: targetId,
                targetName: targetInfo.targetName,
                projectInfo: projectInfo
            )
        } catch {
            logger.error("Error in buildSourcesItem: \(error)")
            return createEmptySourcesItem(for: targetId)
        }
    }

    private func buildSourcesItemFromIndex(
        targetId: BuildTargetIdentifier,
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) async -> SourcesItem {
        // Get source files directly from buildSettingsForIndex
        let sourceItems = await buildSourceItemsFromIndexSettings(
            targetName: targetName,
            projectInfo: projectInfo
        )

        // Use project root as the source root
        let projectRootURI = try? URI(string: projectInfo.rootURL.absoluteString)
        let roots = projectRootURI.map { [$0] } ?? []

        logger
            .info(
                "Built SourcesItem for target '\(targetName)' with \(sourceItems.count) sources and \(roots.count) roots"
            )

        return SourcesItem(
            target: targetId,
            sources: sourceItems,
            roots: roots
        )
    }

    /// Parse target identifier URI to extract target information
    private func parseTargetIdentifier(_ uri: String) throws -> TargetInfo {
        // Expected format: "xcode:///ProjectName/SchemeName/TargetName"
        // But target name is always the last component
        guard let url = URL(string: uri) else {
            throw NSError(
                domain: "InvalidTargetURI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid target URI format"]
            )
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 1 else {
            let message = "Target URI must have at least one path component for target name"
            throw NSError(
                domain: "InvalidTargetURI",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        // Target name is always the last component
        let targetName = pathComponents.last!

        return TargetInfo(
            projectName: pathComponents.count >= 3 ? pathComponents[0] : "",
            schemeName: pathComponents.count >= 3 ? pathComponents[1] : "",
            targetName: targetName
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
        // Debug: Check if buildSettingsForIndex exists
        if projectInfo.buildSettingsForIndex == nil {
            logger.error("buildSettingsForIndex is nil")
            return []
        }

        let indexSettings = projectInfo.buildSettingsForIndex!
        logger.debug("buildSettingsForIndex has \(indexSettings.count) targets: \(Array(indexSettings.keys))")
        logger.debug("Looking for target name: '\(targetName)'")

        // Debug: Print exact key matching
        for key in indexSettings.keys {
            logger.debug("Available key: '\(key)' (matches: \(key == targetName))")
        }

        guard let targetFiles = indexSettings[targetName] else {
            logger.warning("No files found for target '\(targetName)'")
            logger.debug("Available targets in buildSettingsForIndex: \(Array(indexSettings.keys))")
            return []
        }

        logger.info("Found \(targetFiles.count) files for target '\(targetName)'")

        var sourceItems: [SourceItem] = []

        for (filePath, fileInfo) in targetFiles {
            logger.debug("Processing file: \(filePath)")
            guard let sourceItem = createSourceItem(
                filePath: filePath,
                fileInfo: fileInfo,
                projectRoot: projectInfo.rootURL
            ) else {
                logger.warning("Failed to create SourceItem for: \(filePath)")
                continue
            }
            sourceItems.append(sourceItem)
        }

        logger.info("Created \(sourceItems.count) source items for target '\(targetName)'")
        return sourceItems
    }

    func createSourceItem(
        filePath: String,
        fileInfo: XcodeFileBuildSettingInfo,
        projectRoot: URL
    ) -> SourceItem? {
        logger.debug("createSourceItem called for: \(filePath)")
        logger.debug("fileInfo.languageDialect: \(String(describing: fileInfo.languageDialect))")

        let fileURL: URL = if filePath.hasPrefix("/") {
            URL(fileURLWithPath: filePath)
        } else {
            projectRoot.appendingPathComponent(filePath)
        }

        guard let uri = try? URI(string: fileURL.absoluteString) else {
            logger.warning("Failed to create URI for file: \(filePath)")
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
        case .none:
            // If languageDialect is nil, try to detect from file extension
            detectLanguageFromExtension(fileURL.pathExtension)
        }

        logger.debug("Detected language: \(String(describing: language)) for file: \(filePath)")

        // Create SourceKitSourceItemData
        let sourceKitData = SourceKitSourceItemData(
            language: language,
            kind: determineSourceKind(fileURL: fileURL, generated: generated),
            outputPath: fileInfo.outputFilePath
        )

        let sourceItem = SourceItem(
            uri: uri,
            kind: .file,
            generated: generated,
            dataKind: .sourceKit,
            data: sourceKitData.encodeToLSPAny()
        )

        logger.debug("Successfully created SourceItem for: \(filePath)")
        return sourceItem
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
    public let id: JSONRPCID?
    public let jsonrpc: String
    public let result: BuildTargetSourcesResult

    public init(id: JSONRPCID? = nil, jsonrpc: String = "2.0", items: [SourcesItem]) {
        self.id = id
        self.jsonrpc = jsonrpc
        self.result = BuildTargetSourcesResult(items: items)
    }
}

public struct BuildTargetSourcesResult: Codable, Hashable, Sendable {
    public let items: [SourcesItem]

    public init(items: [SourcesItem]) {
        self.items = items
    }
}

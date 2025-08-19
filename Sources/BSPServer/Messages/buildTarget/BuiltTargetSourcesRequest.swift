//
import JSONRPCConnection

//  BuiltTargetSourcesRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

/// Example request:
/// ```json
/// {
///   "params": {
///     "targets": [
///       {"uri": "xcode:///path/to/Hello.xcodeproj/Hello/Hello"},
///       {"uri": "xcode:///path/to/Hello.xcodeproj/Hello/HelloTests"},
///       {"uri": "xcode:///path/to/Hello.xcodeproj/Hello/HelloUITests"},
///       {"uri": "xcode:///path/to/Hello.xcodeproj/Hello/World"}
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
    typealias RequiredContext = BSPServerService

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
    ) async -> ResponseType? where Handler.Context == BSPServerService {
        await contextualHandler.withContext { context in
            await handleBuildTargetSources(service: context, targetIds: params.targets, requestId: id)
        }
    }

    private func handleBuildTargetSources(
        service: BSPServerService,
        targetIds: [BuildTargetIdentifier],
        requestId: RequestID
    ) async -> BuildTargetSourcesResponse {
        var sourcesItems = [SourcesItem]()
        for targetId in targetIds {
            logger.debug("Processing target: \(targetId.uri.stringValue)")
            let sourcesItem = await buildSourcesItem(
                for: targetId,
                service: service
            )
            sourcesItems.append(sourcesItem)
        }
        return BuildTargetSourcesResponse(id: requestId, items: sourcesItems)
    }

    private func buildSourcesItem(
        for targetIdentifier: BuildTargetIdentifier,
        service: BSPServerService
    ) async -> SourcesItem {
        do {
            // 异步并行处理目标解析和项目信息获取
            let targetInfo = try self.parseTargetIdentifier(targetIdentifier.uri.stringValue)
            guard let projectManager = await service.getCurrentProjectManager(),
                  let projectInfo = await projectManager.currentProject else {
                logger.error("Project not initialized")
                return SourcesItem(target: targetIdentifier, sources: [])
            }

            logger
                .debug("Parsed target - projectURL: \(targetInfo.projectURL), " +
                    "targetName: \(targetInfo.targetName)")

            // Build sources directly from buildSettingsForIndex
            // Extract underlying XcodeProjectInfo if available
//            let xcodeProjectInfo: XcodeProjectInfo
//            if let adapter = projectInfo as? XcodeProjectInfoAdapter {
//                xcodeProjectInfo = adapter.underlyingXcodeProjectInfo
//            } else {
//                logger.error("Project is not an Xcode project, cannot build sources")
//                return createEmptySourcesItem(for: targetIdentifier)
//            }
            // TODO: fix here
            fatalError()
//            return await buildSourcesItemFromIndex(
//                targetIdentifier: targetIdentifier,
//                targetName: targetInfo.targetName,
//                projectInfo: xcodeProjectInfo
//            )
        } catch {
            logger.error("Error in buildSourcesItem: \(error)")
            return createEmptySourcesItem(for: targetIdentifier)
        }
    }

    private func buildSourcesItemFromIndex(
        targetIdentifier: BuildTargetIdentifier,
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) async -> SourcesItem {
        // 从target URI中提取blueprintIdentifier用于查找buildSettingsForIndex
        let targetURI = targetIdentifier.uri.stringValue
        logger.debug("Building sources for target URI: \(targetURI)")

        // 异步并行处理URI转换和源文件构建
        async let sourceItems = buildSourceItemsFromIndexSettings(
            targetIdentifierValue: targetURI,
            targetName: targetName,
            projectInfo: projectInfo
        )

        let projectRootURI = convertProjectRootURI(projectInfo.rootURL)

        // 等待两个异步操作完成
        let (items, rootURI) = await (sourceItems, projectRootURI)
        let roots = rootURI.map { [$0] } ?? []

        logger
            .info(
                "Built SourcesItem for target '\(targetName)' with \(items.count) sources " +
                    "and \(roots.count) roots"
            )

        return SourcesItem(
            target: targetIdentifier,
            sources: items,
            roots: roots
        )
    }

    // 异步URI转换辅助方法
    private func convertProjectRootURI(_ rootURL: URL) -> URI? {
        try? URI(string: rootURL.absoluteString)
    }

    /// Parse target identifier URI to extract target information
    private func parseTargetIdentifier(_ uri: String) throws -> TargetInfo {
        // Expected format: "xcode:///ProjectPath/TargetName"
        // But target name is always the last component
        guard let url = URL(string: uri) else {
            throw NSError(
                domain: "InvalidTargetURI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid target URI format"]
            )
        }

        let targetName = url.lastPathComponent
        let projectURL = url.deletingLastPathComponent().absoluteString

        return TargetInfo(
            projectURL: projectURL,
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
        targetIdentifierValue: String,
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) -> [SourceItem] {
        let indexSettings = projectInfo.buildSettingsForIndex
        logger.debug("buildSettingsForIndex has \(indexSettings.count) targets: \(Array(indexSettings.keys))")
        logger.debug("Looking for targetIdentifier: '\(targetIdentifierValue)', targetName: '\(targetName)'")

        var targetFiles: [String: XcodeFileBuildSettingInfo]?

        // 尝试多种查找策略：
        // 1. 直接使用targetIdentifier（向后兼容）
        if let files = indexSettings[targetIdentifierValue] {
            targetFiles = files
        } else {
            // 2. 尝试查找包含targetName的键（处理blueprintIdentifier格式）
            for (key, files) in indexSettings where key.contains(targetName) {
                // 检查键是否匹配target信息
                targetFiles = files
                logger.debug("Found target using key containing targetName: '\(key)'")
                break
            }
        }

        // 3. 如果还没找到，打印所有可用的键帮助调试
        if targetFiles == nil {
            logger.warning("No files found for target '\(targetName)' with identifier '\(targetIdentifierValue)'")
            logger.debug("Available keys in buildSettingsForIndex: \(Array(indexSettings.keys))")
            return []
        }

        guard let foundFiles = targetFiles else {
            return []
        }

        logger.info("Found \(foundFiles.count) files for target '\(targetName)'")

        var sourceItems: [SourceItem] = []
        for (filePath, fileInfo) in foundFiles {
            let item = self.createSourceItem(
                filePath: filePath,
                fileInfo: fileInfo,
                projectRoot: projectInfo.rootURL
            )
            if let item {
                sourceItems.append(item)
            }
        }
        return sourceItems
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
            logger.warning("Failed to create URI for file: \(filePath)")
            return nil
        }

        // Determine if the file is generated
        let generated = filePath.contains("DerivedData") ||
            filePath.contains("Build/") ||
            filePath.contains("build/") ||
            filePath.hasSuffix(".generated.swift")

        // Determine language based on file type
        let language: Language? = Language(
            xcodeLanguageDialect: fileInfo.languageDialect,
            fileExtension: fileURL.pathExtension
        )

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

        return sourceItem
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
    let projectURL: String
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

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
        // 异步并行处理所有目标
        let items = await withTaskGroup(of: SourcesItem.self) { group in
            for targetId in targetIds {
                group.addTask {
                    await buildSourcesItem(
                        for: targetId,
                        context: context
                    )
                }
            }

            var results: [SourcesItem] = []
            for await item in group {
                results.append(item)
            }
            return results
        }

        return BuildTargetSourcesResponse(id: requestId, items: items)
    }

    private func buildSourcesItem(
        for targetId: BuildTargetIdentifier,
        context: BuildServerContext
    ) async -> SourcesItem {
        do {
            // 异步并行处理目标解析和项目信息获取
            async let targetInfo = parseTargetIdentifierAsync(targetId.uri.stringValue)
            async let projectInfo = context.getProjectBasicInfo()

            // 等待两个异步操作完成
            let (parsedTargetInfo, basicInfo) = try await (targetInfo, projectInfo)

            logger.debug("Parsed target info - projectName: \(parsedTargetInfo.projectName), " +
                "schemeName: \(parsedTargetInfo.schemeName), targetName: \(parsedTargetInfo.targetName)")

            // Build sources directly from buildSettingsForIndex
            return await buildSourcesItemFromIndex(
                targetId: targetId,
                targetName: parsedTargetInfo.targetName,
                projectInfo: basicInfo
            )
        } catch {
            logger.error("Error in buildSourcesItem: \(error)")
            return createEmptySourcesItem(for: targetId)
        }
    }

    // 异步版本的目标解析方法
    private func parseTargetIdentifierAsync(_ uri: String) async throws -> TargetInfo {
        try await Task.detached(priority: .utility) {
            try self.parseTargetIdentifier(uri) // 保持原有逻辑不变
        }.value
    }

    private func buildSourcesItemFromIndex(
        targetId: BuildTargetIdentifier,
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) async -> SourcesItem {
        // 从target URI中提取blueprintIdentifier用于查找buildSettingsForIndex
        let targetURI = targetId.uri.stringValue
        logger.debug("Building sources for target URI: \(targetURI)")

        // 异步并行处理URI转换和源文件构建
        async let sourceItems = buildSourceItemsFromIndexSettings(
            targetURI: targetURI,
            targetName: targetName,
            projectInfo: projectInfo
        )

        async let projectRootURI = convertProjectRootURIAsync(projectInfo.rootURL)

        // 等待两个异步操作完成
        let (items, rootURI) = await (sourceItems, projectRootURI)
        let roots = rootURI.map { [$0] } ?? []

        logger
            .info(
                "Built SourcesItem for target '\(targetName)' with \(items.count) sources " +
                    "and \(roots.count) roots"
            )

        return SourcesItem(
            target: targetId,
            sources: items,
            roots: roots
        )
    }

    // 异步URI转换辅助方法
    private func convertProjectRootURIAsync(_ rootURL: URL) async -> URI? {
        await Task.detached(priority: .utility) {
            try? URI(string: rootURL.absoluteString)
        }.value
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
        targetURI: String,
        targetName: String,
        projectInfo: XcodeProjectInfo
    ) async -> [SourceItem] {
        // 获取缓存数据
        await Task.detached(priority: .userInitiated) {
            // Debug: Check if buildSettingsForIndex exists
            guard let indexSettings = projectInfo.buildSettingsForIndex else {
                logger.error("buildSettingsForIndex is nil")
                return []
            }

            logger.debug("buildSettingsForIndex has \(indexSettings.count) targets: \(Array(indexSettings.keys))")
            logger.debug("Looking for target URI: '\(targetURI)', targetName: '\(targetName)'")

            // 直接使用 projectPath/targetName 格式的键（完整路径）
            var targetFiles: [String: XcodeFileBuildSettingInfo]?

            if let projectPathAndTarget = self.extractProjectPathAndTarget(from: targetURI) {
                logger.debug("🔍 Extracted projectPath/target: '\(projectPathAndTarget)' from URI: '\(targetURI)'")
                targetFiles = indexSettings[projectPathAndTarget]
                if targetFiles != nil {
                    logger.debug("✅ Found target using projectPath/target key: '\(projectPathAndTarget)'")
                } else {
                    logger.warning("❌ No files found for projectPath/target key: '\(projectPathAndTarget)'")
                }
            } else {
                logger.error("❌ Failed to extract projectPath/target from URI: '\(targetURI)'")
            }

            // 4. 如果还没找到，打印所有可用的键帮助调试
            if targetFiles == nil {
                logger.warning("No files found for target '\(targetName)' with URI '\(targetURI)'")
                logger.debug("Available keys in buildSettingsForIndex: \(Array(indexSettings.keys))")
                return []
            }

            guard let foundFiles = targetFiles else {
                return []
            }

            logger.info("Found \(foundFiles.count) files for target '\(targetName)'")

            // 异步并行处理文件转换
            return await withTaskGroup(of: SourceItem?.self) { group in
                for (filePath, fileInfo) in foundFiles {
                    group.addTask {
                        await self.createSourceItemAsync(
                            filePath: filePath,
                            fileInfo: fileInfo,
                            projectRoot: projectInfo.rootURL
                        )
                    }
                }

                var sourceItems: [SourceItem] = []
                for await sourceItem in group {
                    if let item = sourceItem {
                        sourceItems.append(item)
                    }
                }

                logger.info("Created \(sourceItems.count) source items for target '\(targetName)'")
                return sourceItems
            }
        }.value
    }

    // 新增异步版本的createSourceItem
    func createSourceItemAsync(
        filePath: String,
        fileInfo: XcodeFileBuildSettingInfo,
        projectRoot: URL
    ) async -> SourceItem? {
        await Task.detached(priority: .utility) {
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
                self.detectLanguageFromExtension(fileURL.pathExtension)
            case .none:
                // If languageDialect is nil, try to detect from file extension
                self.detectLanguageFromExtension(fileURL.pathExtension)
            }

            logger.debug("Detected language: \(String(describing: language)) for file: \(filePath)")

            // Create SourceKitSourceItemData
            let sourceKitData = SourceKitSourceItemData(
                language: language,
                kind: self.determineSourceKind(fileURL: fileURL, generated: generated),
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
        }.value
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

    /// Extract project path and target name from BSP target URI (without scheme query)
    /// Returns: "projectPath/targetName" that can be used as a key for buildSettingsForIndex
    func extractProjectPathAndTarget(from uriString: String) -> String? {
        guard uriString.hasPrefix("xcode://") else { return nil }
        guard URL(string: uriString) != nil else { return nil }

        // Remove scheme:// prefix and query parameters
        let pathWithTarget = uriString.dropFirst("xcode://".count)

        // Split by '?' to remove query parameters
        let pathOnly = String(pathWithTarget.split(separator: "?").first ?? "")

        return pathOnly
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

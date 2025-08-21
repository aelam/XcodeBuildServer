//
//  BSPServerService+BuildTargetSources.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import Foundation

extension BSPServerService {
    func getSourcesItems(targetIds: [BuildTargetIdentifier]) async throws -> [SourcesItem] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project manager not initialized")
        }

        guard let projectInfo = await projectManager.projectInfo else {
            throw BuildServerError.invalidConfiguration("projectInfo is not loaded")
        }

        let targetWithIdMap: [String: ProjectTarget] = Dictionary(
            uniqueKeysWithValues: projectInfo.targets.map {
                ($0.targetIndentifier, $0)
            }
        )

        return targetIds.map { targetIdentifier in
            guard let target = targetWithIdMap[targetIdentifier.uri.stringValue] else {
                return nil
            }
            return createSourcesItem(
                targetIdentifier: targetIdentifier,
                projectInfo: projectInfo,
                target: target
            )
        }.compactMap(\.self)
    }

    // MARK: - Create [SourcesItem]

    private func createSourcesItem(
        targetIdentifier: BSPBuildTargetIdentifier,
        projectInfo: ProjectInfo,
        target: ProjectTarget
    ) -> SourcesItem {
        var sourceItemList: [SourceItem] = []
        for fileURL in target.sourceFiles {
            let item = self.createSourceItem(
                fileURL: fileURL,
                fileInfo: nil,
                projectRoot: projectInfo.rootURL
            )
            if let item {
                sourceItemList.append(item)
            }
        }

        return SourcesItem(
            target: targetIdentifier,
            sources: sourceItemList,
            roots: []
        )
    }

    // MARK: - Create [SourceItem]

    func createSourceItem(
        fileURL: URL,
        fileInfo: FileBuildSettingInfo?,
        projectRoot: URL
    ) -> SourceItem? {
        let filePath = fileURL.absoluteString
        guard let uri = try? URI(string: filePath) else {
            logger.warning("Failed to create URI for file: \(filePath)")
            return nil
        }

        // Determine if the file is generated
        let generated = filePath.contains("DerivedData") ||
            filePath.contains("/.Build/") ||
            filePath.contains("/.build/") ||
            filePath.hasSuffix(".generated.swift")

        // Determine language based on file type
        let language: Language? = fileInfo?.language ?? Language(
            inferredFromFileExtension: fileURL
        )

        // Create SourceKitSourceItemData
        let sourceKitData = SourceKitSourceItemData(
            language: language,
            kind: determineSourceKind(fileURL: fileURL, generated: generated),
            outputPath: fileInfo?.outputFilePath
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

    private func determineSourceKind(fileURL: URL, generated: Bool) -> SourceKitSourceItemKind {
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

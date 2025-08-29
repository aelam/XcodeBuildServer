//
//  BSPServerService+BuildTargetSources.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import BuildServerProtocol
import Foundation

extension BSPServerService {
    func getSourcesItems(targetIds: [BSPBuildTargetIdentifier]) async throws -> [SourcesItem] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project manager not initialized")
        }

        guard let projectInfo = await projectManager.projectInfo else {
            throw BuildServerError.invalidConfiguration("projectInfo is not loaded")
        }

        return await withTaskGroup(of: SourcesItem.self, returning: [SourcesItem].self) { taskGroup in
            for targetIdentifier in targetIds {
                taskGroup.addTask {
                    await self.createSourcesItem(
                        targetIdentifier: targetIdentifier,
                        projectManager: projectManager,
                        projectInfo: projectInfo
                    )
                }
            }

            var sourcesItemList = [SourcesItem]()
            for await result in taskGroup {
                sourcesItemList.append(result)
            }

            return sourcesItemList
        }
    }

    // MARK: - Create [SourcesItem]

    private func createSourcesItem(
        targetIdentifier: BSPBuildTargetIdentifier,
        projectManager: any ProjectManager,
        projectInfo: ProjectInfo,
    ) async -> SourcesItem {
        let soureceFileURLs = await projectManager.getSourceFileList(targetIdentifier: targetIdentifier.uri.stringValue)

        var sourceItemList: [SourceItem] = []

        for fileURL in soureceFileURLs {
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

    private func createSourceItem(
        fileURL: URL,
        fileInfo: FileBuildSettingInfo?,
        projectRoot: URL
    ) -> SourceItem? {
        let filePath = fileURL.absoluteString
        let uri = URI(fileURL)

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

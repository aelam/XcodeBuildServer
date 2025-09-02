import Foundation
import PathKit
import XcodeProj

enum SourceFileLister {
    // MARK: - SourceFiles

    typealias SourceMap = [String: [SourceItem]]

    static func loadSourceFiles(
        for xcodeProj: XcodeProj,
        targets: Set<String>
    ) -> SourceMap {
        guard let xcodeProjPath = xcodeProj.path else {
            print(
                "Cannot open Xcode project at \(xcodeProj.path?.string ?? "unknown path")"
            )
            return SourceMap()
        }
        let sourceRoot = xcodeProjPath.parent()
        var sourceMap = SourceMap()

        for target in xcodeProj.pbxproj.nativeTargets
            where targets.contains(target.name) {
            var sourceItems = [SourceItem]()

            // Xcode15+：fileSystemSynchronizedGroups
            if let syncGroupIDs = target.fileSystemSynchronizedGroups {
                sourceItems = sourceFilesFromSynchronizedGroups(
                    syncGroupIDs,
                    xcodeProj: xcodeProj,
                    sourceRoot: sourceRoot
                )
            } else {
                // 旧结构：SourcesBuildPhase
                sourceItems += sourceFilesFromBuildPhases(
                    target,
                    sourceRoot: sourceRoot
                )
            }

            // 去重
            sourceItems = Array(Set(sourceItems))
            let targetIdentifier = XcodeTargetIdentifier(
                projectFilePath: xcodeProjPath.string,
                targetName: target.name
            )
            sourceMap[targetIdentifier.rawValue] = sourceItems
        }
        return sourceMap
    }

    // 辅助方法：从同步 group 获取源码文件
    private static func sourceFilesFromSynchronizedGroups(
        _ syncGroupIDs: [PBXFileSystemSynchronizedRootGroup],
        xcodeProj: XcodeProj,
        sourceRoot: Path
    ) -> [SourceItem] {
        syncGroupIDs.compactMap { groupID -> SourceItem? in
            guard let folderPath = groupID.path else {
                return nil // 如果没有路径，就丢掉
            }
            let fullFolderPath = sourceRoot + Path(folderPath)

            var path = fullFolderPath.string
            if !path.hasSuffix("/") {
                path += "/"
            }

            return SourceItem(
                path: URL(filePath: path),
                itemKind: .directory
            )
        }
    }

    // 辅助方法：从 build phase 获取源码文件
    private static func sourceFilesFromBuildPhases(
        _ target: PBXNativeTarget,
        sourceRoot: Path
    ) -> [SourceItem] {
        target.buildPhases.compactMap { $0 as? PBXSourcesBuildPhase }
            .flatMap { sourcesPhase in
                (sourcesPhase.files ?? []).compactMap { buildFile in
                    guard let fileRef = buildFile.file else { return nil }
                    if let full = try? fileRef.fullPath(sourceRoot: sourceRoot)?
                        .string {
                        return full
                    } else if let rel = fileRef.path {
                        return (sourceRoot + Path(rel)).string
                    } else {
                        print("Cannot resolve path for \(fileRef)")
                        return nil
                    }
                }
            }
            .map { fullPath in
                SourceItem(path: URL(filePath: fullPath), itemKind: .file)
            }
    }
}

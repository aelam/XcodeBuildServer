import Foundation
import Logger
import PathKit
import XcodeProj

enum IndexSettingsGeneration {
    static func generate(
        rootURL: URL,
        buildSettingsMap: XcodeBuildSettingsMap
    ) -> XcodeBuildSettingsForIndex {
        // sourceMap: [targetIdentifier: [filePath]]
        let sourceMap = loadSourceFiles(targetIdentifierRawValues: Array(buildSettingsMap.keys))

        var indexSettings: XcodeBuildSettingsForIndex = [:]
        for (targetIdentifier, settings) in buildSettingsMap {
            // 获取该 target 的所有 source file 路径
            let sourceFiles = sourceMap[targetIdentifier] ?? []
            var fileInfos: [String: XcodeFileBuildSettingInfo] = [:]
            for sourceFile in sourceFiles {
                let languageDialect = analyzeLanguageDialect(for: sourceFile)
                // 构造 buildSettingInfo
                let buildSettingInfo = XcodeFileBuildSettingInfo(
                    assetSymbolIndexPath: settings.buildSettings["ASSET_SYMBOL_INDEX_PATH"],
                    clangASTBuiltProductsDir: settings.buildSettings["CLANG_AST_BUILT_PRODUCTS_DIR"],
                    clangASTCommandArguments: settings.buildSettings["CLANG_AST_COMMAND_ARGUMENTS"]?
                        .components(separatedBy: " "),
                    clangPrefixFilePath: settings.buildSettings["CLANG_PREFIX_HEADER"],
                    languageDialect: languageDialect,
                    outputFilePath: settings.buildSettings["OUTPUT_FILE_PATH"] ?? sourceFile,
                    swiftASTBuiltProductsDir: settings.buildSettings["SWIFT_AST_BUILT_PRODUCTS_DIR"],
                    swiftASTCommandArguments: settings.buildSettings["SWIFT_AST_COMMAND_ARGUMENTS"]?
                        .components(separatedBy: " "),
                    swiftASTModuleName: settings.buildSettings["SWIFT_MODULE_NAME"],
                    toolchains: settings.buildSettings["TOOLCHAINS"]?.components(separatedBy: " ")
                )
                fileInfos[sourceFile] = buildSettingInfo
            }
            indexSettings[targetIdentifier] = fileInfos
        }
        return indexSettings
    }

    // MARK: - Languages

    private static func analyzeLanguageDialect(for filePath: String) -> XcodeLanguageDialect? {
        let ext = (filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return .swift
        case "m":
            return .objc
        case "mm":
            return .objcCpp
        case "cpp", "cxx", "cc":
            return .cpp
        case "c":
            return .c
        case "metal":
            return .metal
        case "storyboard", "xib":
            return .interfaceBuilder
        default:
            return nil
        }
    }

    // MARK: - SourceFiles

    typealias SourceMap = [String: [String]]
    private static func loadSourceFiles(targetIdentifierRawValues: [String]) -> SourceMap {
        let identifiers = targetIdentifierRawValues.map { TargetIdentifier(rawValue: $0) }
        // 用 Dictionary(grouping:by:) 一步分组
        // [ projectFilePath: ]
        // 分组 targetName 为 Set，自动去重
        let groupedTargetNames = Dictionary(
            grouping: identifiers
        ) { $0.projectFilePath }
            .mapValues { Set($0.map(\.targetName)) }

        var sourceMap = SourceMap()
        for (projectFilePath, targetNames) in groupedTargetNames {
            let sourceMapForProject = loadSourceFiles(for: Path(projectFilePath), targets: targetNames)
            sourceMap.merge(sourceMapForProject) { _, new in new }
        }
        return sourceMap
    }

    private static func loadSourceFiles(for projectFileURL: Path, targets: Set<String>) -> SourceMap {
        guard let xcodeProj = try? XcodeProj(path: projectFileURL) else {
            print("Cannot open Xcode project at \(projectFileURL)")
            return SourceMap()
        }
        let sourceRoot = projectFileURL.parent()
        var sourceMap = SourceMap()

        for target in xcodeProj.pbxproj.nativeTargets where targets.contains(target.name) {
            var filePaths = [String]()

            // Xcode15+：fileSystemSynchronizedGroups
            if let syncGroupIDs = target.fileSystemSynchronizedGroups {
                filePaths += sourceFilesFromSynchronizedGroups(
                    syncGroupIDs,
                    xcodeProj: xcodeProj,
                    sourceRoot: sourceRoot
                )
            }

            // 旧结构：SourcesBuildPhase
            filePaths += sourceFilesFromBuildPhases(target, sourceRoot: sourceRoot)

            // 去重
            filePaths = Array(Set(filePaths))
            let targetIdentifier = TargetIdentifier(projectFilePath: projectFileURL.string, targetName: target.name)
            sourceMap[targetIdentifier.rawValue] = filePaths
        }
        return sourceMap
    }

    // 辅助方法：从同步 group 获取源码文件
    private static func sourceFilesFromSynchronizedGroups(
        _ syncGroupIDs: [PBXFileSystemSynchronizedRootGroup],
        xcodeProj: XcodeProj,
        sourceRoot: Path
    ) -> [String] {
        syncGroupIDs.flatMap { groupID in
            guard
                let folderPath = groupID.path
            else {
                return [String]()
            }
            let fullFolderPath = sourceRoot + Path(folderPath)
            let fileList = (try? FileManager.default.contentsOfDirectory(atPath: fullFolderPath.string)) ?? []
            return fileList.filter { isSourceFile($0) }
                .map { (fullFolderPath + Path($0)).string }
        }
    }

    // 辅助方法：从 build phase 获取源码文件
    private static func sourceFilesFromBuildPhases(_ target: PBXNativeTarget, sourceRoot: Path) -> [String] {
        target.buildPhases.compactMap { $0 as? PBXSourcesBuildPhase }
            .flatMap { sourcesPhase in
                (sourcesPhase.files ?? []).compactMap { buildFile in
                    guard let fileRef = buildFile.file else { return nil }
                    if let full = try? fileRef.fullPath(sourceRoot: sourceRoot)?.string {
                        return full
                    } else if let rel = fileRef.path {
                        return (sourceRoot + Path(rel)).string
                    } else {
                        print("Cannot resolve path for \(fileRef)")
                        return nil
                    }
                }
            }
    }

    // 辅助方法：判断是否为源码文件
    private static func isSourceFile(_ filename: String) -> Bool {
        let exts = [".swift", ".m", ".mm", ".c", ".cpp", ".h"]
        return exts.contains { filename.hasSuffix($0) }
    }
}

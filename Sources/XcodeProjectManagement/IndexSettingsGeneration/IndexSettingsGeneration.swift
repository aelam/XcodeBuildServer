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
            grouping: identifiers,
            by: { $0.projectFilePath }
        )
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

        for target in xcodeProj.pbxproj.nativeTargets {
            guard targets.contains(target.name) else { continue }
            var filePaths: [String] = []

            // Xcode15 Project file：通过 fileSystemSynchronizedGroups 获取本地文件夹
            if let syncGroupIDs = target.fileSystemSynchronizedGroups {
                for groupID in syncGroupIDs {
                    guard let folderPath = groupID.path else {
                        continue
                    }
                    let fullFolderPath = sourceRoot + Path(folderPath)
                    // 遍历文件夹下所有源码文件（只遍历一层，如需递归可修改）
                    if let fileList = try? FileManager.default.contentsOfDirectory(atPath: fullFolderPath.string) {
                        let sourceFiles = fileList.filter {
                            $0.hasSuffix(".swift") || $0.hasSuffix(".m") || $0.hasSuffix(".mm") ||
                                $0.hasSuffix(".c") || $0.hasSuffix(".cpp") || $0.hasSuffix(".h")
                        }.map { (fullFolderPath + Path($0)).string }
                        filePaths.append(contentsOf: sourceFiles)
                    }
                }
            }
            // 兼容旧结构：SourcesBuildPhase
            let sourcesPhases = target.buildPhases.compactMap { $0 as? PBXSourcesBuildPhase }
            for sourcesPhase in sourcesPhases {
                for buildFile in sourcesPhase.files ?? [] {
                    if let fileRef = buildFile.file {
                        if let full = try? fileRef.fullPath(sourceRoot: sourceRoot)?.string {
                            filePaths.append(full)
                        } else if let rel = fileRef.path {
                            let resolved = (sourceRoot + Path(rel)).string
                            filePaths.append(resolved)
                        } else {
                            print("Cannot resolve path for \(fileRef)")
                        }
                    }
                }
            }

            // 去重
            filePaths = Array(Set(filePaths))

            let targetIdentifier = TargetIdentifier(projectFilePath: projectFileURL.string, targetName: target.name)
            sourceMap[targetIdentifier.rawValue] = filePaths
        }
        return sourceMap
    }
}

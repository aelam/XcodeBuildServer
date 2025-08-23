import Foundation
import Logger
import PathKit
import XcodeProj

enum IndexSettingsGeneration {
    static func generate(
        rootURL: URL,
        xcodeProjectBuildSettings: XcodeProjectProjectBuildSettings,
        buildSettingsMap: XcodeBuildSettingsMap
    ) -> XcodeBuildSettingsForIndex {
        // sourceMap: [targetIdentifier: [filePath]]
        let sourceMap = loadSourceFiles(targetIdentifierRawValues: Array(buildSettingsMap.keys))

        // Create project-level configuration once (shared across all targets)
        let projectConfig = ProjectConfig(projectBuildSettings: xcodeProjectBuildSettings, rootURL: rootURL)

        var indexSettings: XcodeBuildSettingsForIndex = [:]
        for (targetIdentifier, settings) in buildSettingsMap {
            let targetProductType = XcodeProductType(rawValue: settings.buildSettings["PRODUCT_TYPE"] ?? "") ?? .none

            // Create target-level configuration once per target
            let targetBuildConfig = TargetBuildConfig(buildSettings: settings, projectConfig: projectConfig)

            // 获取该 target 的所有 source file 路径
            let sourceFiles = sourceMap[targetIdentifier] ?? []
            let swiftSourceFiles = sourceFiles.filter { $0.hasSuffix(".swift") }
            var fileInfos: [String: XcodeFileBuildSettingInfo] = [:]
            for sourceFile in sourceFiles {
                let fileExtension = (sourceFile as NSString).pathExtension.lowercased()
                let language = XcodeLanguageDialect(fileExtension: fileExtension)

                // Create appropriate file config based on language
                let fileConfig: any SourceFileBuildConfigurable = if language.isSwift {
                    SwiftFileBuildConfig(
                        targetBuildConfig: targetBuildConfig,
                        sourceFile: sourceFile,
                        language: language,
                        context: SwiftFileBuildConfig.SwiftBuildContext(
                            targetProductType: targetProductType,
                            sourceFiles: swiftSourceFiles
                        )
                    )
                } else {
                    ClangFileBuildConfig(
                        targetBuildConfig: targetBuildConfig,
                        sourceFile: sourceFile,
                        language: language
                    )
                }

                // 构造 buildSettingInfo
                let buildSettingInfo = XcodeFileBuildSettingInfo(
                    assetSymbolIndexPath: targetBuildConfig.buildAssetSymbolIndexPath(),
                    clangASTBuiltProductsDir: language.isClang ? fileConfig.ASTBuiltProductsDir : nil,
                    clangASTCommandArguments: language.isClang ? fileConfig.ASTCommandArguments : [],
                    clangPrefixFilePath: targetBuildConfig.clangPrefixFilePath,
                    languageDialect: language,
                    outputFilePath: fileConfig.outputFilePath,
                    swiftASTBuiltProductsDir: language.isSwift ? fileConfig.ASTBuiltProductsDir : nil,
                    swiftASTCommandArguments: language.isSwift ? fileConfig.ASTCommandArguments : nil,
                    swiftASTModuleName: fileConfig.ASTModuleName,
                    toolchains: targetBuildConfig.toolchains
                )
                fileInfos[sourceFile] = buildSettingInfo
            }
            indexSettings[targetIdentifier] = fileInfos
        }
        return indexSettings
    }
}

extension IndexSettingsGeneration {
    // MARK: - SourceFiles

    typealias SourceMap = [String: [String]]
    fileprivate static func loadSourceFiles(targetIdentifierRawValues: [String]) -> SourceMap {
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

enum StringUtils {
    static func splitFlags(_ command: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        var escape = false

        for char in command {
            if escape {
                current.append(char)
                escape = false
            } else if char == "\\" {
                escape = true
            } else if char == "\"" {
                insideQuotes.toggle()
            } else if char == " ", !insideQuotes {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}

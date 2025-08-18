import Foundation
import Logger
import PathKit
import XcodeProj

enum IndexSettingsGeneration {
    static func generate(
        rootURL: URL,
        primaryBuildSettings: XcodeProjectPrimaryBuildSettings,
        buildSettingsMap: XcodeBuildSettingsMap
    ) -> XcodeBuildSettingsForIndex {
        // sourceMap: [targetIdentifier: [filePath]]
        let sourceMap = loadSourceFiles(targetIdentifierRawValues: Array(buildSettingsMap.keys))

        var indexSettings: XcodeBuildSettingsForIndex = [:]
        for (targetIdentifier, settings) in buildSettingsMap {
            let targetProductType = XcodeProductType(rawValue: settings.buildSettings["PRODUCT_TYPE"] ?? "") ?? .none

            // 获取该 target 的所有 source file 路径
            let sourceFiles = sourceMap[targetIdentifier] ?? []
            var fileInfos: [String: XcodeFileBuildSettingInfo] = [:]
            for sourceFile in sourceFiles {
                let languageDialect = buildLanguageDialect(for: sourceFile)
                // 构造 buildSettingInfo
                let buildSettingInfo = XcodeFileBuildSettingInfo(
                    assetSymbolIndexPath: buildAssetSymbolIndexPath(buildSettings: settings),
                    clangASTBuiltProductsDir: settings.buildSettings["CONFIGURATION_BUILD_DIR"],
                    clangASTCommandArguments: settings.buildSettings["CLANG_AST_COMMAND_ARGUMENTS"]?
                        .components(separatedBy: " "),
                    clangPrefixFilePath: settings.buildSettings["CLANG_PREFIX_HEADER"],
                    languageDialect: languageDialect,
                    outputFilePath: buildOutputFilePath(for: sourceFile, buildSettings: settings),
                    swiftASTBuiltProductsDir: buildSwiftASTBuiltProductsDir(buildSettings: settings),
                    swiftASTCommandArguments: buildSwiftASTCommandArguments(
                        for: sourceFile,
                        targetProductType: targetProductType,
                        primaryBuildSettings: primaryBuildSettings,
                        buildSettings: settings,
                        sourceFiles: sourceFiles
                    ),
                    swiftASTModuleName: settings.buildSettings["PRODUCT_MODULE_NAME"],
                    toolchains: settings.buildSettings["TOOLCHAINS"]?.components(separatedBy: " ")
                )
                fileInfos[sourceFile] = buildSettingInfo
            }
            indexSettings[targetIdentifier] = fileInfos
        }
        return indexSettings
    }
}

private extension IndexSettingsGeneration {
    // MARK: - Languages

    static func buildLanguageDialect(for filePath: String) -> XcodeLanguageDialect? {
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
}

private extension IndexSettingsGeneration {
    // "assetSymbolIndexPath" : "/Users/wang.lun/Library/Developer/Xcode/DerivedData/UserStickers-bjpqwcrhbrjlmmgoukkubiwvgigd/Build/Intermediates.noindex/Pods.build/Debug-iphonesimulator/Crossroad.build/DerivedSources/GeneratedAssetSymbols-Index.plist",
    // $(DERIVED_DATA_DIR)/$(PROJECT_NAME)-<hash>/Build/Intermediates.noindex/Pods.build/$(CONFIGURATION)-$(EFFECTIVE_PLATFORM_NAME)/$(TARGET_NAME).build/DerivedSources/GeneratedAssetSymbols-Index.plist

    // MARK: - assetSymbolIndexPath

    static func buildAssetSymbolIndexPath(buildSettings: XcodeBuildSettings) -> String {
        let buildSettingsPair = extractBuildSettingsPair(from: buildSettings)
        let pathComponents = buildAssetSymbolIndexPathComponents(from: buildSettingsPair)
        return pathComponents.joined(separator: "/")
    }

    private static func extractBuildSettingsPair(from buildSettings: XcodeBuildSettings) -> [String: String] {
        buildSettings.buildSettings
    }

    private static func buildAssetSymbolIndexPathComponents(from buildSettingsPair: [String: String]) -> [String] {
        let objRoot = buildSettingsPair["OBJROOT"] ?? "/tmp/OBJROOT"
        let projectName = buildSettingsPair["PROJECT"] ?? ""
        let configuration = buildSettingsPair["CONFIGURATION"] ?? "Debug"
        let effectivePlatformName = buildSettingsPair["EFFECTIVE_PLATFORM_NAME"] ?? "-iphonesimulator"
        let moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? ""

        return [
            objRoot,
            "\(projectName).build", // Pods.build
            "\(configuration)\(effectivePlatformName)", // Debug-iphonesimulator
            "\(moduleName).build", // Crossroad.build
            "DerivedSources",
            "GeneratedAssetSymbols-Index.plist"
        ]
    }
}

private extension IndexSettingsGeneration {
    // MARK: - swiftASTBuiltProductsDir

    static func buildSwiftASTBuiltProductsDir(buildSettings: XcodeBuildSettings) -> String {
        let configurationBuildDir = buildSettings.buildSettings["CONFIGURATION_BUILD_DIR"] ?? "/tmp/"
        let moduleName = buildSettings.buildSettings["PRODUCT_MODULE_NAME"] ?? buildSettings.target
        return [configurationBuildDir, moduleName].joined(separator: "/")
    }

    // MARK: - outputFilePath

    static func buildOutputFilePath(for filePath: String, buildSettings: XcodeBuildSettings) -> String {
        let buildSettingsPair: [String: String] = buildSettings.buildSettings
        let projectName = buildSettingsPair["PROJECT"] ?? ""
        let moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? ""
        let configuration = buildSettingsPair["CONFIGURATION"] ?? "Debug"
        let effectivePlatformName = buildSettingsPair["EFFECTIVE_PLATFORM_NAME"] ?? "-iphonesimulator"
        let arch = buildSettingsPair["NATIVE_ARCH"] ?? "arm64"
        let outputName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent

        let components: [String] =
            [
                projectName + ".build", // Pods.build
                configuration + effectivePlatformName, // Debug-iphonesimulator
                moduleName + ".build", // Crossroad.build
                "Objects-normal",
                arch,
                outputName + ".o",
            ]
        return "/" + components.joined(separator: "/")
    }
}

// MARK: - swiftASTCommandArguments

private extension IndexSettingsGeneration {
    // MARK: - buildSwiftASTCommandArguments

    static func buildSwiftASTCommandArguments(
        for filePath: String,
        targetProductType: XcodeProductType,
        primaryBuildSettings: XcodeProjectPrimaryBuildSettings,
        buildSettings: XcodeBuildSettings,
        sourceFiles: [String]
    ) -> [String] {
        let buildConfig = SwiftBuildConfig(
            buildSettings: buildSettings,
            primaryBuildSettings: primaryBuildSettings
        )

        let basicFlags = buildBasicSwiftFlags(config: buildConfig)
        let searchPathFlags = buildSearchPathFlags(config: buildConfig)
        let testFlags = buildTestFlags(config: buildConfig, targetProductType: targetProductType)
        let conditionFlags = buildCompilationConditionFlags(config: buildConfig)
        let swiftFlags = buildSwiftSpecificFlags(config: buildConfig, sourceFiles: sourceFiles)
        let cacheFlags = buildCacheAndProductFlags(config: buildConfig)
        let advancedFlags = buildAdvancedCompilerFlags(config: buildConfig)

        return basicFlags
            + searchPathFlags
            + testFlags
            + conditionFlags
            + swiftFlags
            + cacheFlags
            + advancedFlags
    }

    private struct SwiftBuildConfig {
        let buildSettingsPair: [String: String]
        let moduleName: String
        let derivedDataPath: URL
        let indexStorePath: String
        let moduleCachePath: String
        let configurationBuildDir: String
        let productPath: String
        let configurationTempDir: String
        let hmapFolder: String
        let swiftOverridesHmapPath: String
        let constExtractProtocols: String
        let vfsoverlayPath: String
        let sdkRoot: String
        let nativeArch: String
        let target: String
        let swiftVersion: String
        let sdkStatCachePath: String
        let gccPreprocessorDefinitions: String

        init(buildSettings: XcodeBuildSettings, primaryBuildSettings: XcodeProjectPrimaryBuildSettings) {
            self.buildSettingsPair = buildSettings.buildSettings
            self.moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? buildSettings.target
            self.derivedDataPath = primaryBuildSettings.derivedDataPath
            self.indexStorePath = primaryBuildSettings.indexStoreURL.path

            self.moduleCachePath = derivedDataPath.deletingLastPathComponent()
                .appendingPathComponent("ModuleCache.noindex")
                .path

            self.configurationBuildDir = buildSettingsPair["CONFIGURATION_BUILD_DIR"] ?? ""
            self.productPath = URL(filePath: configurationBuildDir).appendingPathComponent(moduleName).path

            self.configurationTempDir = buildSettingsPair["CONFIGURATION_TEMP_DIR"] ?? ""
            self.hmapFolder = URL(filePath: configurationTempDir).appendingPathComponent("\(moduleName).build").path
            self.swiftOverridesHmapPath = URL(filePath: hmapFolder).appendingPathComponent("swift-overrides.hmap").path

            self.constExtractProtocols = URL(fileURLWithPath: buildSettingsPair["PER_ARCH_MODULE_FILE_DIR"] ?? "")
                .deletingLastPathComponent()
                .appendingPathComponent(buildSettingsPair["NATIVE_ARCH"] ?? "arm64")
                .appendingPathComponent("\(moduleName)_const_extract_protocols.json")
                .path

            let projectGUID = buildSettingsPair["PROJECT_GUID"] ?? ""
            let platform = buildSettingsPair["PLATFORM_NAME"] ?? "iphonesimulator"
            self.vfsoverlayPath = configurationTempDir +
                "\(moduleName)-\(projectGUID)-VFS-\(platform)/all-product-headers.yaml"

            self.sdkRoot = buildSettingsPair["SDKROOT"] ?? ""
            self.nativeArch = buildSettingsPair["NATIVE_ARCH"] ?? "arm64"

            let vendor = buildSettingsPair["LLVM_TARGET_TRIPLE_VENDOR"] ?? "apple"
            let osVersion = buildSettingsPair["LLVM_TARGET_TRIPLE_OS_VERSION"] ?? "ios16.0"
            let suffix = (buildSettingsPair["LLVM_TARGET_TRIPLE_SUFFIX"] ?? "-simulator").replacingOccurrences(
                of: "-",
                with: ""
            )
            self.target = [nativeArch, vendor, osVersion, suffix].joined(separator: "-")

            self.swiftVersion = buildSettingsPair["SWIFT_VERSION"] ?? "5"
            self.sdkStatCachePath = buildSettingsPair["SDK_STAT_CACHE_PATH"] ?? ""
            self.gccPreprocessorDefinitions = buildSettingsPair["GCC_PREPROCESSOR_DEFINITIONS"] ?? ""
        }
    }

    private static func buildBasicSwiftFlags(config: SwiftBuildConfig) -> [String] {
        [
            "-module-name", config.moduleName,
            "-Onone",
            "-enforce-exclusivity=checked",
            "-enable-bare-slash-regex",
            "-enable-experimental-feature",
            "DebugDescriptionMacro",
            "-sdk", config.sdkRoot,
            "-target", config.target,
            "-g",
            "-module-cache-path", config.moduleCachePath,
            "-Xcc", "-fmodules-cache-path=\(config.moduleCachePath)",
            "-Xfrontend",
            "-serialize-debugging-options",
            "-profile-coverage-mapping",
            "-profile-generate",
            "-enable-testing",
            "-index-store-path", config.indexStorePath,
            "-swift-version", config.swiftVersion
        ]
    }

    private static func buildSearchPathFlags(config: SwiftBuildConfig) -> [String] {
        let headerSearchFlags = extractHeaderSearchFlags(from: config.buildSettingsPair)
        let frameworkSearchFlags = extractFrameworkSearchFlags(from: config.buildSettingsPair)
        let librarySearchFlags = extractLibrarySearchFlags(from: config.buildSettingsPair)
        let linkerFlags = extractLinkerFlags(from: config.buildSettingsPair)

        return headerSearchFlags + frameworkSearchFlags + librarySearchFlags + linkerFlags
    }

    private static func buildTestFlags(config: SwiftBuildConfig, targetProductType: XcodeProductType) -> [String] {
        guard targetProductType.isTestType else { return [] }

        let testFrameworkFlags = extractTestFrameworkSearchFlags(from: config.buildSettingsPair)
        let testLibraryFlags = extractTestLibrarySearchFlags(from: config.buildSettingsPair)
        let testHostAppFlags = extractTestHostAppSwiftModuleFlags(from: config.buildSettingsPair)

        return testFrameworkFlags + testLibraryFlags + testHostAppFlags
    }

    private static func buildCompilationConditionFlags(config: SwiftBuildConfig) -> [String] {
        guard let conditions = config.buildSettingsPair["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] else {
            return []
        }
        return conditions.split(separator: " ").map { "-D\($0)" }
    }

    private static func buildSwiftSpecificFlags(config: SwiftBuildConfig, sourceFiles: [String]) -> [String] {
        let otherSwiftFlagsString = config.buildSettingsPair["OTHER_SWIFT_FLAGS"] ?? ""
        let otherSwiftFlags = StringUtils.splitFlags(otherSwiftFlagsString)

        return sourceFiles + otherSwiftFlags
    }

    private static func buildCacheAndProductFlags(config: SwiftBuildConfig) -> [String] {
        let productFlags: [String] = [
            "-Xcc", "-I", "-Xcc", config.productPath,
            "-I", config.productPath,
            "-Xcc", "-F", "-Xcc", config.productPath,
            "-F", config.productPath
        ]

        let batchFlags: [String] = [
            "-c", "-j14", "-enable-batch-mode",
            "-Xcc", "-ivfsstatcache", "-Xcc", config.sdkStatCachePath,
            "-I\(config.swiftOverridesHmapPath)"
        ]

        let protocolFlags: [String] = [
            "-emit-const-values",
            "-Xfrontend",
            "-const-gather-protocols-file",
            "-Xfrontend",
            config.constExtractProtocols
        ]

        return productFlags + batchFlags + protocolFlags
    }

    private static func buildAdvancedCompilerFlags(config: SwiftBuildConfig) -> [String] {
        let hmapFlags: [String] = [
            "-Xcc", "-iquote", "-Xcc", config.swiftOverridesHmapPath + "\(config.moduleName)-generated-files.hmap",
            "-Xcc", "-I\(config.swiftOverridesHmapPath)" + "\(config.moduleName)-own-target-headers.hmap",
            "-Xcc", "-I\(config.swiftOverridesHmapPath)" + "\(config.moduleName)-all-non-framework-target-headers.hmap"
        ]

        let vfsoverlayFlags: [String] = [
            "-Xcc", "-ivfsoverlay", "-Xcc", config.vfsoverlayPath
        ]

        let projectHeadersFlags: [String] = [
            "-Xcc", "-iquote", "-Xcc", config.swiftOverridesHmapPath + "\(config.moduleName)-project-headers.hmap"
        ]

        let includeFlags: [String] = [
            "-Xcc", "-I\(config.configurationBuildDir)/\(config.moduleName)/include"
        ]

        let derivedSourcesFlags: [String] = [
            "-Xcc",
            "-I\(config.configurationTempDir)/\(config.moduleName).build/DerivedSources-normal/\(config.nativeArch)",
            "-Xcc", "-I\(config.configurationTempDir)/\(config.moduleName).build/DerivedSources/\(config.nativeArch)",
            "-Xcc", "-I\(config.configurationTempDir)/\(config.moduleName).build/DerivedSources/"
        ]

        let gccFlags: [String] = StringUtils.splitFlags(config.gccPreprocessorDefinitions)

        let underlyingModuleFlags: [String] = [
            "-import-underlying-module",
            "-Xcc", "-ivfsoverlay", "-Xcc",
            config.configurationTempDir + "\(config.moduleName).build/unextended-module-overlay.yaml"
        ]

        let workingDirFlags: [String] = [
            "-working-directory",
            config.buildSettingsPair["PROJECT_DIR"] ?? ""
        ]

        let extraFlags: [String] = [
            "-Xcc", "-fretain-comments-from-system-headers",
            "-Xcc", "-Xclang",
            "-Xcc", "-detailed-preprocessing-record",
            "-Xcc", "-Xclang",
            "-Xcc", "-fmodule-format=raw",
            "-Xcc", "-Xclang",
            "-Xcc", "-fallow-pch-with-compiler-errors",
            "-Xcc", "-Wno-non-modular-include-in-framework-module",
            "-Xcc", "-Wno-incomplete-umbrella",
            "-Xcc", "-fmodules-validate-system-headers"
        ]

        return hmapFlags + vfsoverlayFlags + projectHeadersFlags + includeFlags
            + derivedSourcesFlags + gccFlags + underlyingModuleFlags + workingDirFlags + extraFlags
    }

    private static func extractHeaderSearchFlags(from buildSettings: [String: String]) -> [String] {
        guard let paths = buildSettings["HEADER_SEARCH_PATHS"] else { return [] }

        let headerSearchPaths = paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }

        return headerSearchPaths.flatMap { ["-Xcc", "-I\($0)"] }
    }

    private static func extractFrameworkSearchFlags(from buildSettings: [String: String]) -> [String] {
        guard let paths = buildSettings["FRAMEWORK_SEARCH_PATHS"] else { return [] }

        return paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .map { "-F\($0)" }
    }

    private static func extractLibrarySearchFlags(from buildSettings: [String: String]) -> [String] {
        guard let paths = buildSettings["LIBRARY_SEARCH_PATHS"] else { return [] }

        return paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .map { "-L\($0)" }
    }

    private static func extractLinkerFlags(from buildSettings: [String: String]) -> [String] {
        // "PRODUCT_SPECIFIC_LDFLAGS" : "-framework XCTest -lXCTestSwiftSupport",
        guard let ldflags = buildSettings["PRODUCT_SPECIFIC_LDFLAGS"] else { return [] }

        return ldflags.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
    }

    private static func extractTestFrameworkSearchFlags(from buildSettings: [String: String]) -> [String] {
        guard let paths = buildSettings["TEST_FRAMEWORK_SEARCH_PATHS"] else { return [] }

        return paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .map { "-F\($0)" }
    }

    private static func extractTestLibrarySearchFlags(from buildSettings: [String: String]) -> [String] {
        guard let paths = buildSettings["TEST_LIBRARY_SEARCH_PATHS"] else { return [] }

        return paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .map { "-L\($0)" }
    }

    private static func extractTestHostAppSwiftModuleFlags(from buildSettings: [String: String]) -> [String] {
        guard let configurationBuildDir = buildSettings["CONFIGURATION_BUILD_DIR"] else {
            return []
        }
        return [
            "-I",
            configurationBuildDir
        ]
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

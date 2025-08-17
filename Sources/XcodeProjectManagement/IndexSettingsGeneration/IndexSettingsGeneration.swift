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
            let identifier = TargetIdentifier(rawValue: targetIdentifier)
            let targetName = identifier.targetName
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
                    swiftASTCommandArguments: settings.buildSettings["SWIFT_AST_COMMAND_ARGUMENTS"]?
                        .components(separatedBy: " "),
                    swiftASTModuleName: settings.buildSettings["PRODUCT_MODULE_NAME"],
                    toolchains: settings.buildSettings["TOOLCHAINS"]?.components(separatedBy: " ")
                )
                fileInfos[sourceFile] = buildSettingInfo
            }
            indexSettings[targetIdentifier] = fileInfos
        }
        return indexSettings
    }

    // MARK: - Languages

    private static func buildLanguageDialect(for filePath: String) -> XcodeLanguageDialect? {
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

    // "assetSymbolIndexPath" : "/Users/wang.lun/Library/Developer/Xcode/DerivedData/UserStickers-bjpqwcrhbrjlmmgoukkubiwvgigd/Build/Intermediates.noindex/Pods.build/Debug-iphonesimulator/Crossroad.build/DerivedSources/GeneratedAssetSymbols-Index.plist",
    // $(DERIVED_DATA_DIR)/$(PROJECT_NAME)-<hash>/Build/Intermediates.noindex/Pods.build/$(CONFIGURATION)-$(EFFECTIVE_PLATFORM_NAME)/$(TARGET_NAME).build/DerivedSources/GeneratedAssetSymbols-Index.plist

    // MARK: - assetSymbolIndexPath

    private static func buildAssetSymbolIndexPath(buildSettings: XcodeBuildSettings) -> String {
        let buildSettingsPair: [String: String] = buildSettings.buildSettings
        let OBJROOT = buildSettingsPair["OBJROOT"] ?? ""
        let projectName = buildSettingsPair["PROJECT"] ?? ""
        let configuration = buildSettingsPair["CONFIGURATION"] ?? "Debug"
        let EFFECTIVE_PLATFORM_NAME = buildSettingsPair["EFFECTIVE_PLATFORM_NAME"] ?? "-iphonesimulator"
        let moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? ""

        return [
            OBJROOT,
            projectName + ".build", // Pods.build
            configuration + EFFECTIVE_PLATFORM_NAME, // Debug-iphonesimulator
            moduleName + ".build", // Crossroad.build
            "DerivedSources",
            "GeneratedAssetSymbols-Index.plist"
        ].joined(separator: "/")
    }

    // MARK: - swiftASTBuiltProductsDir

    private static func buildSwiftASTBuiltProductsDir(buildSettings: XcodeBuildSettings) -> String {
        let CONFIGURATION_BUILD_DIR = buildSettings.buildSettings["CONFIGURATION_BUILD_DIR"] ?? ""
        let moduleName = buildSettings.buildSettings["PRODUCT_MODULE_NAME"] ?? buildSettings.target
        return [CONFIGURATION_BUILD_DIR, moduleName].joined(separator: "/")
    }

    // MARK: - outputFilePath

    private static func buildOutputFilePath(for filePath: String, buildSettings: XcodeBuildSettings) -> String {
        let buildSettingsPair: [String: String] = buildSettings.buildSettings
        let projectName = buildSettingsPair["PROJECT"] ?? ""
        let moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? ""
        let configuration = buildSettingsPair["CONFIGURATION"] ?? "Debug"
        let EFFECTIVE_PLATFORM_NAME = buildSettingsPair["EFFECTIVE_PLATFORM_NAME"] ?? "-iphonesimulator"
        let arch = buildSettingsPair["NATIVE_ARCH"] ?? "arm64"
        let outputName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent

        let components: [String] =
            [
                projectName + ".build", // Pods.build
                configuration + EFFECTIVE_PLATFORM_NAME, // Debug-iphonesimulator
                moduleName + ".build", // Crossroad.build
                "Objects-normal",
                arch,
                outputName + ".o",
            ]
        return "/" + components.joined(separator: "/")
    }

    // MARK: - swiftASTCommandArguments

    private func buildSwiftASTCommandArguments(
        for filePath: String,
        buildSettings: XcodeBuildSettings,
        sourceFiles: [String]
    ) -> [String] {
        let buildSettingsPair: [String: String] = buildSettings.buildSettings
        let moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? buildSettings.target
        let otherSwiftFlagsString = buildSettingsPair["OTHER_SWIFT_FLAGS"] ?? ""
        let otherSwiftFlags = StringUtils.splitFlags(otherSwiftFlagsString)
        let SDKROOT = buildSettingsPair["SDKROOT"] ?? ""

        // "arm64-apple-ios16.0-simulator",
        let NATIVE_ARCH = buildSettingsPair["NATIVE_ARCH"] ?? "arm64"
        let vendor = buildSettingsPair["LLVM_TARGET_TRIPLE_VENDOR"] ?? "apple"
        let osVersion = buildSettingsPair["LLVM_TARGET_TRIPLE_OS_VERSION"] ?? "ios16.0"
        let suffix = (buildSettingsPair["LLVM_TARGET_TRIPLE_SUFFIX"] ?? "-simulator").replacingOccurrences(
            of: "-",
            with: ""
        )
        let target = [NATIVE_ARCH, vendor, osVersion, suffix].joined() // "arm64-apple-ios16.0-simulator",

        // moduleCachePath
        let moduleCachePath = buildSettingsPair["MODULE_CACHE_DIR"] ?? ""
        let indexStorePath = URL(fileURLWithPath: buildSettingsPair["BUILD_DIR"] ?? "")
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Index.noindex/DataStore").absoluteString
        let swiftVersion = buildSettingsPair["SWIFT_VERSION"] ?? "5"

        let configurationBuildDir = buildSettingsPair["CONFIGURATION_BUILD_DIR"] ?? ""
        let productPath = configurationBuildDir + moduleName

        let SDK_STAT_CACHE_PATH = buildSettingsPair["SDK_STAT_CACHE_PATH"] ?? ""

        // "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphoneos/Hello.build/swift-overrides.hmap",
        // "CONFIGURATION_TEMP_DIR" : "/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphonesimulator",
        let CONFIGURATION_TEMP_DIR = buildSettingsPair["CONFIGURATION_TEMP_DIR"] ?? ""
        let hmapFolder = CONFIGURATION_TEMP_DIR + "\(moduleName).build" + "/"
        let swiftOverridesHmapPath = hmapFolder + "swift-overrides.hmap"

        // "PER_ARCH_MODULE_FILE_DIR" : "/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphonesimulator/Hello.build/Objects-normal/undefined_arch",
        // "-Xfrontend",
        // "/Users/wang.lun/Library/Developer/Xcode/DerivedData/UserStickers-bjpqwcrhbrjlmmgoukkubiwvgigd/Build/Intermediates.noindex/Pods.build/Debug-iphonesimulator/Crossroad.build/Objects-normal/arm64/Crossroad_const_extract_protocols.json",
        let const_extract_protocols = URL(fileURLWithPath: buildSettingsPair["PER_ARCH_MODULE_FILE_DIR"] ?? "")
            .deletingLastPathComponent()
            .appendingPathComponent(NATIVE_ARCH)
            .appendingPathComponent("\(moduleName)_const_extract_protocols.json")
            .absoluteString

        let projectGUID = buildSettingsPair["PROJECT_GUID"] ?? ""
        let platform = buildSettingsPair["PLATFORM_NAME"] ?? "iphonesimulator"

        let vfsoverlayPath = CONFIGURATION_TEMP_DIR + "\(moduleName)-\(projectGUID)-VFS-\(platform)/all-product-headers.yaml"

        let GCC_PREPROCESSOR_DEFINITIONS = buildSettingsPair["GCC_PREPROCESSOR_DEFINITIONS"] ?? ""

        return [
            "-module-name", moduleName,
            "-Onone",
            "-enforce-exclusivity=checked",
        ] +
            sourceFiles +
            otherSwiftFlags +
            [
                "-enable-bare-slash-regex",
                "-enable-experimental-feature",
                "DebugDescriptionMacro",
                "-sdk", SDKROOT,
                "-target", target, // "arm64-apple-ios16.0-simulator"
                "-g",
                // moduleCachePath
                "-module-cache-path", moduleCachePath,
                "-Xfrontend",
                "-serialize-debugging-options",
                "-profile-coverage-mapping",
                "-profile-generate",
                "-enable-testing",
                // indexStorePath
                "-index-store-path", indexStorePath,
                // swiftVersion
                "-swift-version", swiftVersion,
            ] +
            [
                // productPath
                "-Xcc", "-I", "-Xcc", productPath,
                "-I", productPath,
                "-Xcc", "-F", "-Xcc", productPath,
                "-F", productPath,
            ] +
            [
                // swiftOverridesHmap
                "-c", "-j14", "-enable-batch-mode",
                "-Xcc", "-ivfsstatcache", "-Xcc", SDK_STAT_CACHE_PATH,
                "-I\(swiftOverridesHmapPath)",
            ] +
            [
                // const_extract_protocols
                "-emit-const-values",
                "-Xfrontend",
                "-const-gather-protocols-file",
                "-Xfrontend",
                const_extract_protocols,
            ] +
            [
                // {module}-generated-files.hmap
                "-Xcc",
                "-iquote",
                "-Xcc",
                swiftOverridesHmapPath + "\(moduleName)-generated-files.hmap",

                // {module}-own-headers.hmap
                "-Xcc",
                "-I\(swiftOverridesHmapPath)" + "\(moduleName)-own-target-headers.hmap",

                // {module}-all-non-framework-target-headers
                "-Xcc",
                "-I\(swiftOverridesHmapPath)" + "\(moduleName)-all-non-framework-target-headers.hmap",
            ] +
            [
                // vfsoverlay
                "-Xcc", "-ivfsoverlay", "-Xcc", vfsoverlayPath,
            ] +
            [
                // {module}-project-headers.hmap
                "-Xcc",
                "-iquote",
                "-Xcc",
                swiftOverridesHmapPath + "\(moduleName)-project-headers.hmap"
            ] +
            [
                //
                "-Xcc",
                "-I\(configurationBuildDir)/\(moduleName)/include",
            ] +
            [
                // DerivedSources
                "-Xcc",
                "-I\(CONFIGURATION_TEMP_DIR)/\(moduleName).build/DerivedSources-normal/\(NATIVE_ARCH)",
                "-Xcc",
                "-I\(CONFIGURATION_TEMP_DIR)/\(moduleName).build/DerivedSources/\(NATIVE_ARCH)",
                "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/UserStickers-bjpqwcrhbrjlmmgoukkubiwvgigd/Build/Intermediates.noindex/Pods.build/Debug-iphonesimulator/Crossroad.build/DerivedSources/arm64",
                "-Xcc",
                "-I\(CONFIGURATION_TEMP_DIR)/\(moduleName).build/DerivedSources/",
            ] +
            StringUtils.splitFlags(GCC_PREPROCESSOR_DEFINITIONS) +
            [
                "-import-underlying-module",
                "-Xcc",
                "-ivfsoverlay",
                "-Xcc",
                CONFIGURATION_TEMP_DIR + "\(moduleName).build/unextended-module-overlay.yaml",
            ] +
            [
                "-working-directory",
                buildSettingsPair["PROJECT_DIR"] ?? "",
            ] +
            [
                "-Xcc",
                "-fretain-comments-from-system-headers",
                "-Xcc",
                "-Xclang",
                "-Xcc",
                "-detailed-preprocessing-record",
                "-Xcc",
                "-Xclang",
                "-Xcc",
                "-fmodule-format=raw",
                "-Xcc",
                "-Xclang",
                "-Xcc",
                "-fallow-pch-with-compiler-errors",
                "-Xcc",
                "-Wno-non-modular-include-in-framework-module",
                "-Xcc",
                "-Wno-incomplete-umbrella",
                "-Xcc",
                "-fmodules-validate-system-headers"
            ]
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

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

        // Create project-level configuration once (shared across all targets)
        let projectConfig = ProjectConfig(primaryBuildSettings: primaryBuildSettings, rootURL: rootURL)

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
                let fileConfig: any SourceFileBuildConfigProtocol = if language.isSwift {
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

protocol SourceFileBuildConfigProtocol {
    var targetBuildConfig: TargetBuildConfig { get }
    var sourceFile: String { get }
    var language: XcodeLanguageDialect { get }
    var outputFilePath: String { get }

    var ASTModuleName: String? { get }
    var ASTBuiltProductsDir: String { get }
    var ASTCommandArguments: [String] { get }
}

// Configuration structures
struct SwiftFileBuildConfig: SourceFileBuildConfigProtocol {
    let targetBuildConfig: TargetBuildConfig
    let sourceFile: String
    let language: XcodeLanguageDialect
    let targetProductType: XcodeProductType
    let sourceFiles: [String]

    init(
        targetBuildConfig: TargetBuildConfig,
        sourceFile: String,
        language: XcodeLanguageDialect,
        context: SwiftBuildContext
    ) {
        self.targetBuildConfig = targetBuildConfig
        self.sourceFile = sourceFile
        self.language = language
        self.targetProductType = context.targetProductType
        self.sourceFiles = context.sourceFiles
    }

    struct SwiftBuildContext {
        let targetProductType: XcodeProductType
        let sourceFiles: [String]

        init(targetProductType: XcodeProductType = .none, sourceFiles: [String] = []) {
            self.targetProductType = targetProductType
            self.sourceFiles = sourceFiles
        }
    }

    // Common computed properties
    var outputFilePath: String {
        targetBuildConfig.buildOutputFilePath(for: sourceFile)
    }

    // Swift-specific computed properties
    var ASTModuleName: String? {
        guard language.isSwift else { return nil }
        return targetBuildConfig.moduleName
    }

    var ASTBuiltProductsDir: String {
        guard language.isSwift else { return "" }
        return targetBuildConfig.configurationBuildDir
            .appendingPathComponent(targetBuildConfig.moduleName)
            .path
    }

    var ASTCommandArguments: [String] {
        guard language.isSwift else { return [] }
        return buildSwiftASTCommandArguments()
    }

    // MARK: - Private Swift Command Building

    private func buildSwiftASTCommandArguments() -> [String] {
        let basicFlags = targetBuildConfig.basicSwiftFlags
        let searchPathFlags = targetBuildConfig.generalSearchPathFlags
        let testFlags = targetBuildConfig.generalTestFlags(targetProductType: targetProductType)
        let conditionFlags = targetBuildConfig.compilationConditionFlags
        let swiftFlags = targetBuildConfig.swiftSpecificFlags(sourceFiles: sourceFiles)
        let cacheFlags = buildCacheAndProductFlags()
        let advancedFlags = buildAdvancedCompilerFlags()

        return basicFlags
            + searchPathFlags
            + testFlags
            + conditionFlags
            + swiftFlags
            + cacheFlags
            + advancedFlags
    }

    private func buildCacheAndProductFlags() -> [String] {
        let frameworkFlags = targetBuildConfig.generalFrameworkPathFlags
        let productFlags: [String] = [
            "-Xcc", "-I", "-Xcc", targetBuildConfig.productPath.path,
            "-I", targetBuildConfig.productPath.path
        ] + frameworkFlags.flatMap { ["-Xcc", $0] } + frameworkFlags

        let sdkStatCacheFlags = targetBuildConfig.generalSDKStatCacheFlags
        let batchFlags: [String] = [
            "-c", "-j14", "-enable-batch-mode"
        ] + sdkStatCacheFlags + [
            "-I\(targetBuildConfig.swiftOverridesHmapPath.path)"
        ]

        let protocolFlags: [String] = [
            "-emit-const-values",
            "-Xfrontend",
            "-const-gather-protocols-file",
            "-Xfrontend",
            targetBuildConfig.constExtractProtocols.path
        ]

        return productFlags + batchFlags + protocolFlags
    }

    private func buildAdvancedCompilerFlags() -> [String] {
        let hmapFlags = TargetBuildConfig.buildHeaderMapFlags(
            hmapBasePath: targetBuildConfig.swiftOverridesHmapPath.path,
            moduleName: targetBuildConfig.moduleName
        )

        let vfsoverlayFlags: [String] = [
            "-Xcc", "-ivfsoverlay", "-Xcc", targetBuildConfig.vfsoverlayPath.path
        ]

        let includeFlags = targetBuildConfig.generalIncludePathFlags
            .flatMap { ["-Xcc", $0] }

        let gccFlags: [String] = StringUtils.splitFlags(targetBuildConfig.gccPreprocessorDefinitions)

        // Objective-C bridging header flags (Swift-specific)
        let bridgingHeaderFlags = buildBridgingHeaderFlags()

        let underlyingModuleFlags: [String] = [
            "-import-underlying-module",
            "-Xcc", "-ivfsoverlay", "-Xcc",
            targetBuildConfig.configurationTempDir
                .appendingPathComponent("\(targetBuildConfig.moduleName).build")
                .appendingPathComponent("unextended-module-overlay.yaml")
                .path
        ]

        let workingDirFlags = targetBuildConfig.generalWorkingDirectoryFlags

        let extraFlags = TargetBuildConfig.buildDebugDiagnosticFlags().flatMap { ["-Xcc", $0] }

        return hmapFlags + vfsoverlayFlags + includeFlags
            + gccFlags + bridgingHeaderFlags + underlyingModuleFlags + workingDirFlags + extraFlags
    }

    // MARK: - Swift-specific Methods

    private func buildBridgingHeaderFlags() -> [String] {
        var flags: [String] = []

        // Add Objective-C bridging header if it exists
        if let bridgingHeader = targetBuildConfig.buildSettings["SWIFT_OBJC_BRIDGING_HEADER"], !bridgingHeader.isEmpty {
            flags.append(contentsOf: ["-import-objc-header", bridgingHeader])
        }

        // Add precompiled header output directory
        if let pchOutputDir = targetBuildConfig.buildSettings["SHARED_PRECOMPS_DIR"], !pchOutputDir.isEmpty {
            flags.append(contentsOf: ["-pch-output-dir", pchOutputDir])
        }

        return flags
    }
}

struct ClangFileBuildConfig: SourceFileBuildConfigProtocol {
    let targetBuildConfig: TargetBuildConfig
    let sourceFile: String
    let language: XcodeLanguageDialect

    init(targetBuildConfig: TargetBuildConfig, sourceFile: String, language: XcodeLanguageDialect) {
        self.targetBuildConfig = targetBuildConfig
        self.sourceFile = sourceFile
        self.language = language
    }

    // Common computed properties
    var outputFilePath: String {
        targetBuildConfig.buildOutputFilePath(for: sourceFile)
    }

    // Clang-specific computed properties
    var ASTModuleName: String? { nil } // Clang does not use module names in the same way

    var clangASTBuiltProductsDir: String? {
        guard language.isClang else { return nil }
        return targetBuildConfig.moduleName
    }

    var ASTBuiltProductsDir: String {
        guard language.isClang else { return "" }
        return targetBuildConfig.moduleName
    }

    var ASTCommandArguments: [String] {
        guard language.isClang else { return [] }

        var flags: [String] = []

        // Language-specific flag
        if let xclag = language.xflag {
            flags.append(contentsOf: ["-x", xclag])
        }

        // Use basic compiler flags from targetBuildConfig
        flags.append(contentsOf: targetBuildConfig.basicCompilerFlags)
        flags.append(contentsOf: ["-isysroot", targetBuildConfig.sdkRoot])
        flags.append(contentsOf: targetBuildConfig.generalSDKStatCacheFlags)

        // Header map flags for Clang
        let hmapFlags = TargetBuildConfig.buildHeaderMapFlags(
            hmapBasePath: targetBuildConfig.clangHmapPath.path,
            moduleName: targetBuildConfig.moduleName
        )
        flags.append(contentsOf: hmapFlags)

        flags.append(contentsOf: targetBuildConfig.generalIncludePathFlags)
        flags.append(contentsOf: targetBuildConfig.generalFrameworkPathFlags)
        flags.append(contentsOf: targetBuildConfig.generalWorkingDirectoryFlags)

        // Debug flags
        let debugFlags = TargetBuildConfig.buildDebugDiagnosticFlags()
        flags.append(contentsOf: debugFlags)

        // Output flags (must be at the end)
        let outputName = URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent
        let outputPath = "/" + [
            targetBuildConfig.projectName + ".build",
            targetBuildConfig.configuration + targetBuildConfig.effectivePlatformName,
            targetBuildConfig.moduleName + ".build",
            "Objects-normal",
            targetBuildConfig.nativeArch,
            outputName + ".o"
        ].joined(separator: "/")

        flags.append(contentsOf: [
            "-fsyntax-only",
            sourceFile,
            "-o", outputPath,
            "-index-unit-output-path", outputPath
        ])

        return flags
    }
}

// MARK: - Enhanced Project Configuration

struct ProjectConfig {
    let rootURL: String
    let derivedDataPath: URL
    let indexStorePath: String
    let moduleCachePath: String

    init(primaryBuildSettings: XcodeProjectPrimaryBuildSettings, rootURL: URL) {
        self.rootURL = rootURL.path
        self.derivedDataPath = primaryBuildSettings.derivedDataPath
        self.indexStorePath = primaryBuildSettings.indexStoreURL.path
        self.moduleCachePath = derivedDataPath.deletingLastPathComponent()
            .appendingPathComponent("ModuleCache.noindex")
            .path
    }
}

struct TargetBuildConfig {
    // Raw build settings (kept for backward compatibility)
    private let buildSettingsPair: [String: String]

    // Accessor for build settings (needed by file configs)
    var buildSettings: [String: String] { buildSettingsPair }

    // Project-level config
    let projectConfig: ProjectConfig

    // Target-level computed properties (cached)
    let moduleName: String
    let targetName: String
    let configuration: String
    let platformName: String // iphonesimulator
    let effectivePlatformName: String // -iphonesimulator
    let nativeArch: String // arm64
    let targetTriple: String // arm64-apple-ios16.0-simulator

    // Paths (computed once)
    let configurationBuildDir: URL
    let configurationTempDir: URL
    let productPath: URL
    let hmapFolder: URL
    let swiftOverridesHmapPath: URL
    let clangHmapPath: URL

    // SDK and toolchain
    let sdkRoot: String
    let sdkStatCachePath: String
    let swiftVersion: String
    let objRoot: String

    // Build-specific
    let projectName: String
    let projectGUID: String
    let gccPreprocessorDefinitions: String
    let clangPrefixFilePath: String?
    let toolchains: [String]?

    // Specialized paths
    let constExtractProtocols: URL
    let vfsoverlayPath: URL

    // Cached general flags (computed once during initialization)
    let generalBasicFlags: [String]
    let generalWorkingDirectoryFlags: [String]
    let generalFrameworkPathFlags: [String]
    let generalIncludePathFlags: [String]
    let generalSDKStatCacheFlags: [String]
    let generalSearchPathFlags: [String]

    init(buildSettings: XcodeBuildSettings, projectConfig: ProjectConfig) {
        self.buildSettingsPair = buildSettings.buildSettings
        self.projectConfig = projectConfig

        // Target-level properties (read once, cached)
        self.moduleName = buildSettingsPair["PRODUCT_MODULE_NAME"] ?? buildSettings.target
        self.targetName = buildSettings.target
        self.configuration = buildSettingsPair["CONFIGURATION"] ?? "Debug"
        self.platformName = buildSettingsPair["PLATFORM_NAME"] ?? "iphonesimulator"
        self.effectivePlatformName = buildSettingsPair["EFFECTIVE_PLATFORM_NAME"] ?? "-iphonesimulator"
        self.nativeArch = buildSettingsPair["NATIVE_ARCH"] ?? "arm64"

        // Build target triple
        self.targetTriple = Self.buildTargetTriple(from: buildSettingsPair, nativeArch: nativeArch)

        // Paths (computed once) - with proper fallbacks
        let buildDir = buildSettingsPair["CONFIGURATION_BUILD_DIR"] ?? "/tmp/build"
        let tempDir = buildSettingsPair["CONFIGURATION_TEMP_DIR"] ?? "/tmp/temp"
        self.configurationBuildDir = URL(fileURLWithPath: buildDir.isEmpty ? "/tmp/build" : buildDir)
        self.configurationTempDir = URL(fileURLWithPath: tempDir.isEmpty ? "/tmp/temp" : tempDir)
        self.productPath = configurationBuildDir.appendingPathComponent(moduleName)
        self.hmapFolder = configurationTempDir.appendingPathComponent("\(moduleName).build")
        self.swiftOverridesHmapPath = hmapFolder.appendingPathComponent("swift-overrides.hmap")
        self.clangHmapPath = hmapFolder

        // SDK and toolchain
        self.sdkRoot = buildSettingsPair["SDKROOT"] ?? ""
        self.sdkStatCachePath = buildSettingsPair["SDK_STAT_CACHE_PATH"] ?? ""
        self.swiftVersion = buildSettingsPair["SWIFT_VERSION"] ?? "5"
        self.objRoot = buildSettingsPair["OBJROOT"] ?? "/tmp/OBJROOT"

        // Build-specific
        self.projectName = buildSettingsPair["PROJECT"] ?? ""
        self.projectGUID = buildSettingsPair["PROJECT_GUID"] ?? ""
        self.gccPreprocessorDefinitions = buildSettingsPair["GCC_PREPROCESSOR_DEFINITIONS"] ?? ""
        self.clangPrefixFilePath = buildSettingsPair["CLANG_PREFIX_HEADER"]
        self.toolchains = buildSettingsPair["TOOLCHAINS"]?.components(separatedBy: " ")

        // Specialized paths
        self.constExtractProtocols = Self.buildConstExtractProtocolsURL(
            buildSettingsPair: buildSettingsPair,
            moduleName: moduleName,
            nativeArch: nativeArch
        )
        self.vfsoverlayPath = configurationTempDir
            .appendingPathComponent("\(moduleName)-\(projectGUID)-VFS-\(platformName)")
            .appendingPathComponent("all-product-headers.yaml")

        // Initialize cached general flags
        self.generalBasicFlags = Self.buildGeneralBasicFlags(
            sdkRoot: sdkRoot,
            targetTriple: targetTriple,
            projectConfig: projectConfig
        )

        self.generalWorkingDirectoryFlags = Self.buildWorkingDirectoryFlags(
            buildSettingsPair: buildSettingsPair,
            projectConfig: projectConfig
        )

        self.generalFrameworkPathFlags = ["-F\(configurationBuildDir.path)"]

        self.generalIncludePathFlags = Self.buildIncludePathFlags(
            configurationBuildDir: configurationBuildDir,
            configurationTempDir: configurationTempDir,
            moduleName: moduleName,
            nativeArch: nativeArch
        )

        self.generalSDKStatCacheFlags = ["-Xcc", "-ivfsstatcache", "-Xcc", sdkStatCachePath]

        // Compute search path flags
        self.generalSearchPathFlags = Self.buildSearchPathFlags(from: buildSettingsPair)
    }

    // General test flags - usable by all languages (computed on demand since they need targetProductType)
    func generalTestFlags(targetProductType: XcodeProductType) -> [String] {
        guard targetProductType.isTestType else { return [] }

        let testFrameworkFlags = Self.extractTestFrameworkSearchFlags(from: buildSettingsPair)
        let testLibraryFlags = Self.extractTestLibrarySearchFlags(from: buildSettingsPair)
        let testHostAppFlags = Self.extractTestHostAppSwiftModuleFlags(from: buildSettingsPair)

        return testFrameworkFlags + testLibraryFlags + testHostAppFlags
    }

    // Module and cache flags
    var moduleCacheFlags: [String] {
        [
            "-module-cache-path", projectConfig.moduleCachePath,
            "-fmodules-cache-path=\(projectConfig.moduleCachePath)"
        ]
    }

    // Basic compiler flags
    var basicCompilerFlags: [String] {
        [
            "-sdk", sdkRoot,
            "-target", targetTriple,
            "-g",
            "-index-store-path", projectConfig.indexStorePath
        ] + moduleCacheFlags
    }

    // Basic Swift flags
    var basicSwiftFlags: [String] {
        basicCompilerFlags + [
            "-module-name", moduleName,
            "-Onone",
            "-enforce-exclusivity=checked",
            "-enable-bare-slash-regex",
            "-enable-experimental-feature",
            "DebugDescriptionMacro",
            "-Xfrontend",
            "-serialize-debugging-options",
            "-profile-coverage-mapping",
            "-profile-generate",
            "-enable-testing",
            "-swift-version", swiftVersion
        ]
    }

    // Compilation condition flags
    var compilationConditionFlags: [String] {
        guard let conditions = buildSettingsPair["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] else {
            return []
        }
        return conditions.split(separator: " ").map { "-D\($0)" }
    }

    // Swift specific flags
    func swiftSpecificFlags(sourceFiles: [String]) -> [String] {
        let otherSwiftFlagsString = buildSettingsPair["OTHER_SWIFT_FLAGS"] ?? ""
        let otherSwiftFlags = StringUtils.splitFlags(otherSwiftFlagsString)

        return sourceFiles + otherSwiftFlags
    }

    // MARK: - Additional build methods moved from IndexSettingsGeneration

    func buildSDKStatCacheFlags() -> [String] {
        generalSDKStatCacheFlags
    }

    func buildWorkingDirectoryFlags() -> [String] {
        generalWorkingDirectoryFlags
    }

    func buildFrameworkPathFlags() -> [String] {
        generalFrameworkPathFlags
    }

    func buildIncludePathFlags() -> [String] {
        generalIncludePathFlags
    }

    static func buildHeaderMapFlags(hmapBasePath: String, moduleName: String) -> [String] {
        [
            "-Xcc", "-iquote", "-Xcc", "\(hmapBasePath)/\(moduleName)-generated-files.hmap",
            "-Xcc", "-I\(hmapBasePath)/\(moduleName)-own-target-headers.hmap",
            "-Xcc", "-I\(hmapBasePath)/\(moduleName)-all-non-framework-target-headers.hmap",
            "-Xcc", "-iquote", "-Xcc", "\(hmapBasePath)/\(moduleName)-project-headers.hmap"
        ]
    }

    static func buildDebugDiagnosticFlags() -> [String] {
        [
            "-fretain-comments-from-system-headers",
            "-Xclang", "-detailed-preprocessing-record",
            "-Xclang", "-fmodule-format=raw",
            "-Xclang", "-fallow-pch-with-compiler-errors",
            "-Wno-non-modular-include-in-framework-module",
            "-Wno-incomplete-umbrella",
            "-fmodules-validate-system-headers"
        ]
    }

    func buildOutputFilePath(for filePath: String) -> String {
        let outputName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent

        let components: [String] = [
            projectName + ".build", // Pods.build
            configuration + effectivePlatformName, // Debug-iphonesimulator
            moduleName + ".build", // Crossroad.build
            "Objects-normal",
            nativeArch,
            outputName + ".o",
        ]
        return "/" + components.joined(separator: "/")
    }

    func buildAssetSymbolIndexPath() -> String {
        let pathComponents = [
            objRoot,
            "\(projectName).build",
            "\(configuration)\(effectivePlatformName)",
            "\(moduleName).build",
            "DerivedSources",
            "GeneratedAssetSymbols-Index.plist"
        ]
        return pathComponents.joined(separator: "/")
    }

    // MARK: - Initialization Helper Methods

    private static func buildTargetTriple(from buildSettingsPair: [String: String], nativeArch: String) -> String {
        let vendor = buildSettingsPair["LLVM_TARGET_TRIPLE_VENDOR"] ?? "apple"
        let osVersion = buildSettingsPair["LLVM_TARGET_TRIPLE_OS_VERSION"] ?? "ios16.0"
        let suffix = (buildSettingsPair["LLVM_TARGET_TRIPLE_SUFFIX"] ?? "-simulator")
            .replacingOccurrences(of: "-", with: "")
        return [nativeArch, vendor, osVersion, suffix].joined(separator: "-")
    }

    private static func buildConstExtractProtocolsURL(
        buildSettingsPair: [String: String],
        moduleName: String,
        nativeArch: String
    ) -> URL {
        let perArchDir = buildSettingsPair["PER_ARCH_MODULE_FILE_DIR"] ?? "/tmp/arch"
        let baseDir = perArchDir.isEmpty ? "/tmp/arch" : perArchDir
        return URL(fileURLWithPath: baseDir)
            .deletingLastPathComponent()
            .appendingPathComponent(nativeArch)
            .appendingPathComponent("\(moduleName)_const_extract_protocols.json")
    }

    private static func buildGeneralBasicFlags(
        sdkRoot: String,
        targetTriple: String,
        projectConfig: ProjectConfig
    ) -> [String] {
        [
            "-sdk", sdkRoot,
            "-target", targetTriple,
            "-g",
            "-index-store-path", projectConfig.indexStorePath,
            "-module-cache-path", projectConfig.moduleCachePath,
            "-fmodules-cache-path=\(projectConfig.moduleCachePath)"
        ]
    }

    private static func buildWorkingDirectoryFlags(
        buildSettingsPair: [String: String],
        projectConfig: ProjectConfig
    ) -> [String] {
        [
            "-working-directory",
            buildSettingsPair["PROJECT_DIR"] ?? projectConfig.rootURL
        ]
    }

    private static func buildIncludePathFlags(
        configurationBuildDir: URL,
        configurationTempDir: URL,
        moduleName: String,
        nativeArch: String
    ) -> [String] {
        let buildDir = configurationTempDir.appendingPathComponent("\(moduleName).build")
        let includeDir = configurationBuildDir.appendingPathComponent(moduleName)
            .appendingPathComponent("include")
        let derivedNormalDir = buildDir
            .appendingPathComponent("DerivedSources-normal")
            .appendingPathComponent(nativeArch)
        let derivedArchDir = buildDir
            .appendingPathComponent("DerivedSources")
            .appendingPathComponent(nativeArch)
        let derivedDir = buildDir.appendingPathComponent("DerivedSources")

        return [
            "-I\(includeDir.path)",
            "-I\(derivedNormalDir.path)",
            "-I\(derivedArchDir.path)",
            "-I\(derivedDir.path)"
        ]
    }

    private static func buildSearchPathFlags(from buildSettingsPair: [String: String]) -> [String] {
        let headerSearchFlags = extractHeaderSearchFlags(from: buildSettingsPair)
        let frameworkSearchFlags = extractFrameworkSearchFlags(from: buildSettingsPair)
        let librarySearchFlags = extractLibrarySearchFlags(from: buildSettingsPair)
        let linkerFlags = extractLinkerFlags(from: buildSettingsPair)
        return headerSearchFlags + frameworkSearchFlags + librarySearchFlags + linkerFlags
    }

    // MARK: - Build Settings Extraction Utilities

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

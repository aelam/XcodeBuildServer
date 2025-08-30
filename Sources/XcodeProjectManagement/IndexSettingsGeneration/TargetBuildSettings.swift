import Foundation

// swiftlint:disable:next type_body_length
struct TargetBuildSettings {
    // Raw build settings (kept for backward compatibility)
    private let buildSettingsPair: [String: String]

    // Accessor for build settings (needed by file configs)
    var buildSettings: [String: String] { buildSettingsPair }

    // Project-level config
    let xcodeGlobalSettings: XcodeGlobalSettings

    // Target-level computed properties (cached)
    let moduleName: String
    let targetName: String
    let configuration: String
    let platformName: String // iphonesimulator
    let effectivePlatformName: String // -iphonesimulator
    let nativeArch: String // arm64
    let targetTriple: String // arm64-apple-ios16.0-simulator, arm64-apple-macos14.0

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

    init(
        buildSettings: XcodeBuildSettings,
        xcodeGlobalSettings: XcodeGlobalSettings
    ) {
        self.buildSettingsPair = buildSettings.buildSettings
        self.xcodeGlobalSettings = xcodeGlobalSettings

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
            xcodeGlobalSettings: xcodeGlobalSettings
        )

        self.generalWorkingDirectoryFlags = Self.buildWorkingDirectoryFlags(
            buildSettingsPair: buildSettingsPair,
            xcodeGlobalSettings: xcodeGlobalSettings
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
        []
//        guard targetProductType.asProductType.isTestType else { return [] }
//
//        let testFrameworkFlags = Self.extractTestFrameworkSearchFlags(from: buildSettingsPair)
//        let testLibraryFlags = Self.extractTestLibrarySearchFlags(from: buildSettingsPair)
//        let testHostAppFlags = Self.extractTestHostAppSwiftModuleFlags(from: buildSettingsPair)
//
//        return testFrameworkFlags + testLibraryFlags + testHostAppFlags
    }

    // Module and cache flags
    var moduleCacheFlags: [String] {
        [
            "-module-cache-path", xcodeGlobalSettings.moduleCachePath.path,
            "-Xcc", "-fmodules-cache-path=\(xcodeGlobalSettings.moduleCachePath.path)"
        ]
    }

    // Basic compiler flags
    var basicCompilerFlags: [String] {
        [
            "-sdk", sdkRoot,
            "-target", targetTriple,
            "-g",
            "-index-store-path", xcodeGlobalSettings.indexStoreURL.path
        ] + moduleCacheFlags
    }

    // Basic Swift flags
    var basicSwiftFlags: [String] {
        [
            "-module-name", moduleName,
            "-Onone", // FIXME: read from settings
            "-enforce-exclusivity=checked",
            "-enable-bare-slash-regex",
            "-enable-experimental-feature",
            "DebugDescriptionMacro"
        ] + basicCompilerFlags + [
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
        let suffix = buildSettingsPair["LLVM_TARGET_TRIPLE_SUFFIX"]?
            .replacingOccurrences(of: "-", with: "")
        return [nativeArch, vendor, osVersion, suffix]
            .compactMap(\.self)
            .joined(separator: "-")
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
        xcodeGlobalSettings: XcodeGlobalSettings
    ) -> [String] {
        [
            "-sdk", sdkRoot,
            "-target", targetTriple,
            "-g",
            "-index-store-path", xcodeGlobalSettings.indexStoreURL.path,
            "-module-cache-path", xcodeGlobalSettings.moduleCachePath.path,
            "-fmodules-cache-path", xcodeGlobalSettings.moduleCachePath.path
        ]
    }

    private static func buildWorkingDirectoryFlags(
        buildSettingsPair: [String: String],
        xcodeGlobalSettings: XcodeGlobalSettings
    ) -> [String] {
        guard let projectDir = buildSettingsPair["PROJECT_DIR"] else {
            return []
        }
        return [
            "-working-directory", projectDir
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

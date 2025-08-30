import Foundation

// Configuration structures
struct SwiftFileBuildSettings: SourceFileBuildConfigurable {
    let targetBuildSettings: TargetBuildSettings
    let sourceFile: String
    let language: XcodeLanguageDialect
    let targetProductType: XcodeProductType
    let sourceFiles: [String]

    init(
        targetBuildSettings: TargetBuildSettings,
        sourceFile: String,
        language: XcodeLanguageDialect,
        context: SwiftBuildContext
    ) {
        self.targetBuildSettings = targetBuildSettings
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
        targetBuildSettings.buildOutputFilePath(for: sourceFile)
    }

    // Swift-specific computed properties
    var ASTModuleName: String? {
        guard language.isSwift else { return nil }
        return targetBuildSettings.moduleName
    }

    var ASTBuiltProductsDir: String {
        guard language.isSwift else { return "" }
        return targetBuildSettings.configurationBuildDir
            .appendingPathComponent(targetBuildSettings.moduleName)
            .path
    }

    var ASTCommandArguments: [String] {
        guard language.isSwift else { return [] }
        return buildSwiftASTCommandArguments()
    }

    // MARK: - Private Swift Command Building

    private func buildSwiftASTCommandArguments() -> [String] {
        let basicFlags = targetBuildSettings.basicSwiftFlags
        let includePathFlags = targetBuildSettings.generalIncludePathFlags.flatMap { ["-Xcc", $0] }
        let frameworkPathFlags = targetBuildSettings.generalFrameworkPathFlags
        let searchPathFlags = targetBuildSettings.generalSearchPathFlags
        let conditionFlags = targetBuildSettings.compilationConditionFlags
        let swiftFlags = targetBuildSettings.swiftSpecificFlags(sourceFiles: sourceFiles)
        let testFlags = targetBuildSettings.generalTestFlags(targetProductType: targetProductType)
        let cacheFlags = buildCacheAndProductFlags()
        let advancedFlags = buildAdvancedCompilerFlags()

        return basicFlags
            + includePathFlags
            + frameworkPathFlags
            + searchPathFlags
            + conditionFlags
            + swiftFlags
            + testFlags
            + cacheFlags
            + advancedFlags
    }

    private func buildCacheAndProductFlags() -> [String] {
        let frameworkFlags = targetBuildSettings.generalFrameworkPathFlags
        let productFlags: [String] = [
            "-Xcc", "-I", "-Xcc", targetBuildSettings.productPath.path,
            "-I", targetBuildSettings.productPath.path
        ] + frameworkFlags.flatMap { ["-Xcc", $0] } + frameworkFlags

        let sdkStatCacheFlags = targetBuildSettings.generalSDKStatCacheFlags
        let batchFlags: [String] = [
            "-c", "-j14", "-enable-batch-mode"
        ] + sdkStatCacheFlags + [
            "-I\(targetBuildSettings.swiftOverridesHmapPath.path)"
        ]

        let protocolFlags: [String] = [
            "-emit-const-values",
            "-Xfrontend",
            "-const-gather-protocols-file",
            "-Xfrontend",
            targetBuildSettings.constExtractProtocols.path
        ]

        return productFlags + batchFlags + protocolFlags
    }

    private func buildAdvancedCompilerFlags() -> [String] {
        let hmapFlags = buildSwiftHeaderMapFlags()

        let vfsoverlayFlags: [String] = [
            "-Xcc", "-ivfsoverlay", "-Xcc", targetBuildSettings.vfsoverlayPath.path
        ]

        let includePathFlags = targetBuildSettings.generalIncludePathFlags
            .flatMap { ["-Xcc", $0] }

        let gccFlags: [String] = StringUtils.splitFlags(targetBuildSettings.gccPreprocessorDefinitions)

        // Objective-C bridging header flags (Swift-specific)
        let bridgingHeaderFlags = buildBridgingHeaderFlags()

        let underlyingModuleFlags: [String] = [
            "-import-underlying-module",
            "-Xcc", "-ivfsoverlay", "-Xcc",
            targetBuildSettings.configurationTempDir
                .appendingPathComponent("\(targetBuildSettings.moduleName).build")
                .appendingPathComponent("unextended-module-overlay.yaml")
                .path
        ]

        let workingDirFlags = targetBuildSettings.generalWorkingDirectoryFlags

        let extraFlags = TargetBuildSettings.buildDebugDiagnosticFlags().flatMap { ["-Xcc", $0] }

        return hmapFlags + vfsoverlayFlags + includePathFlags
            + gccFlags + bridgingHeaderFlags + underlyingModuleFlags + workingDirFlags + extraFlags
    }

    // MARK: - Swift-specific Methods

    private func buildBridgingHeaderFlags() -> [String] {
        var flags: [String] = []

        // Add Objective-C bridging header if it exists
        if let bridgingHeader = targetBuildSettings.buildSettings["SWIFT_OBJC_BRIDGING_HEADER"],
           !bridgingHeader.isEmpty {
            flags.append(contentsOf: ["-import-objc-header", bridgingHeader])
        }

        // Add precompiled header output directory
        if let pchOutputDir = targetBuildSettings.buildSettings["SHARED_PRECOMPS_DIR"], !pchOutputDir.isEmpty {
            flags.append(contentsOf: ["-pch-output-dir", pchOutputDir])
        }

        return flags
    }

    // MARK: - Private Swift Helper Methods

    private func buildSwiftHeaderMapFlags() -> [String] {
        let hmapBasePath = targetBuildSettings.hmapFolder.path
        let moduleName = targetBuildSettings.moduleName

        return [
            "-Xcc", "-iquote", "-Xcc", "\(hmapBasePath)/\(moduleName)-generated-files.hmap",
            "-Xcc", "-I\(hmapBasePath)/\(moduleName)-own-target-headers.hmap",
            "-Xcc", "-I\(hmapBasePath)/\(moduleName)-all-target-headers.hmap",
            "-Xcc", "-iquote", "-Xcc", "\(hmapBasePath)/\(moduleName)-project-headers.hmap"
        ]
    }
}

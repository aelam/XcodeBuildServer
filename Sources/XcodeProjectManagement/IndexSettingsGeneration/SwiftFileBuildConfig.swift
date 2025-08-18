import Foundation

// Configuration structures
struct SwiftFileBuildConfig: SourceFileBuildConfigurable {
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
        let includePathFlags = targetBuildConfig.generalIncludePathFlags.flatMap { ["-Xcc", $0] }
        let frameworkPathFlags = targetBuildConfig.generalFrameworkPathFlags
        let searchPathFlags = targetBuildConfig.generalSearchPathFlags
        let conditionFlags = targetBuildConfig.compilationConditionFlags
        let swiftFlags = targetBuildConfig.swiftSpecificFlags(sourceFiles: sourceFiles)
        let testFlags = targetBuildConfig.generalTestFlags(targetProductType: targetProductType)
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
        let hmapFlags = buildSwiftHeaderMapFlags()

        let vfsoverlayFlags: [String] = [
            "-Xcc", "-ivfsoverlay", "-Xcc", targetBuildConfig.vfsoverlayPath.path
        ]

        let includePathFlags = targetBuildConfig.generalIncludePathFlags
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

        return hmapFlags + vfsoverlayFlags + includePathFlags
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

    // MARK: - Private Swift Helper Methods

    private func buildSwiftHeaderMapFlags() -> [String] {
        let hmapBasePath = targetBuildConfig.hmapFolder.path
        let moduleName = targetBuildConfig.moduleName

        return [
            "-Xcc", "-iquote", "-Xcc", "\(hmapBasePath)/\(moduleName)-generated-files.hmap",
            "-Xcc", "-I\(hmapBasePath)/\(moduleName)-own-target-headers.hmap",
            "-Xcc", "-I\(hmapBasePath)/\(moduleName)-all-target-headers.hmap",
            "-Xcc", "-iquote", "-Xcc", "\(hmapBasePath)/\(moduleName)-project-headers.hmap"
        ]
    }
}

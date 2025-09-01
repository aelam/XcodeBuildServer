import Foundation
import XcodeProj

struct ArgContext {
    let buildSettings: [String: String]
    let languageDialect: XcodeLanguageDialect
    let compiler: CompilerType
    let fileURL: URL?
    let sourceItems: [SourceItem]
    let derivedDataPath: URL
    let xcodeInstallation: XcodeInstallation?
}

protocol CompileArgProvider: Sendable {
    func arguments(for context: ArgContext) -> [String]
}

protocol BuildSettingResolvable: Sendable {
    func resolve(forKey key: String) -> String?
    func resolveFileCompilerFlags(for fileURL: URL) -> [String]?
}

struct CompileArgGenerator: Sendable {
    let argContext: ArgContext
    let providers: [CompileArgProvider]

    func compileArguments() -> [String] {
        var args: [String] = []
        for provider in providers {
            args += provider.arguments(for: argContext)
        }
        return args
    }
}

extension CompileArgGenerator {
    static func create(
        xcodeInstallation: XcodeInstallation,
        xcodeGlobalSettings: XcodeGlobalSettings,
        xcodeProj: XcodeProj,
        target: String,
        configurationName: String = "Debug",
        fileURL: URL,
        sourceItems: [SourceItem] = []
    ) throws -> CompileArgGenerator {
        let buildSettings = try BuildSettingResolver(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: target,
            configuration: configurationName
        )

        let languageDialect = XcodeLanguageDialect(fileExtension: fileURL.pathExtension)
        let argContext = ArgContext(
            buildSettings: buildSettings.resolvedBuildSettings,
            languageDialect: languageDialect,
            compiler: languageDialect.isSwift ? .swift : .clang,
            fileURL: fileURL,
            sourceItems: sourceItems,
            derivedDataPath: xcodeGlobalSettings.derivedDataPath,
            xcodeInstallation: xcodeInstallation
        )

        let providers: [CompileArgProvider] = [
            // Platform
            SDKProvider(),
            TargetTripleProvider(),
            // CompilerOptions
            ClangProvider(),
            ClangWarningProvider(),
            GCCWarningProvider(),
            ModuleProvider(),
            ObjectiveCFeaturesProvider(),
            SwiftProvider(),
            SwiftFilesProvider(),
            PCHProvider(),

            // SearchPaths
            HeaderSearchPathProvider(),
            LibrarySearchPathProvider(),
            FrameworkSearchPathProvider(),
            HeaderMapProvider(),
            DerivedSourcesProvider(),
            VFSOverlayProvider(),

            // Toolchain and DerivedData
            SDKStatCacheProvider(),
            IndexStoreProvider(),
            OutputProvider(),
        ]

        return CompileArgGenerator(
            argContext: argContext,
            providers: providers
        )
    }
}

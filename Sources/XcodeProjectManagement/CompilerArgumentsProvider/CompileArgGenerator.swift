import Foundation
import XcodeProj

struct ArgContext {
    let buildSettings: [String: String]
    let compiler: CompilerType
    let fileURL: URL?
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
        fileURL: URL
    ) throws -> CompileArgGenerator {
        let buildSettings = try BuildSettingResolver(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: target,
            configuration: configurationName
        )

        let argContext = ArgContext(
            buildSettings: buildSettings.resolvedBuildSettings,
            compiler: XcodeLanguageDialect(fileExtension: fileURL.pathExtension).isSwift ? .swift : .clang,
            fileURL: fileURL,
            derivedDataPath: xcodeGlobalSettings.derivedDataPath,
            xcodeInstallation: xcodeInstallation
        )

        let providers: [CompileArgProvider] = [
            // Platform
            SDKProvider(),
            TargetTripleProvider(),
            // CompilerOptions
            ClangWarningProvider(),
            GCCWarningProvider(),
            ModuleProvider(),
            ObjectiveCFeaturesProvider(),
            SwiftProvider(),

            // SearchPaths
            HeaderMapProvider(),
            DerivedSourcesProvider(),
            // Toolchain and DerivedData
            SDKStatCacheProvider(),
            IndexStoreProvider()
        ]

        return CompileArgGenerator(
            argContext: argContext,
            providers: providers
        )
    }
}

import Foundation
import XcodeProj

protocol CompileArgProvider: Sendable {
    func arguments(for fileURL: URL, compilerType: CompilerType) -> [String]
}

struct CompileArgGenerator: Sendable {
    let providers: [CompileArgProvider]

    func compileArguments(
        for fileURL: URL,
        compilerType: CompilerType
    ) -> [String] {
        var args: [String] = []
        for provider in providers {
            args += provider.arguments(for: fileURL, compilerType: compilerType)
        }
        args.append(fileURL.path)
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
        let providers: [CompileArgProvider] = try [
            ResolverProvider(
                resolver: BuildSettingResolver(
                    xcodeInstallation: xcodeInstallation,
                    xcodeGlobalSettings: xcodeGlobalSettings,
                    xcodeProj: xcodeProj,
                    target: target,
                    configuration: configurationName
                ),
                compilerType: XcodeLanguageDialect(fileExtension: fileURL
                    .pathExtension
                ).isSwift ? .swift : .clang
            ),
            HeaderMapProvider(derivedDataPath: xcodeGlobalSettings
                .derivedDataPath
            ),
            IndexStoreProvider(derivedDataPath: xcodeGlobalSettings
                .derivedDataPath
            ),
            DerivedSourcesProvider(derivedDataPath: xcodeGlobalSettings
                .derivedDataPath
            ),
            ClangWarningProvider()
        ]

        return CompileArgGenerator(providers: providers)
    }
}

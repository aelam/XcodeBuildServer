import Foundation
import XcodeProj

public struct CompilerFlagMapping: Sendable {
    let buildSetting: String
    let appliesTo: Set<CompilerType>
    let transform: @Sendable (String) -> [String]
}

public struct ResolverProvider: CompileArgProvider, Sendable {
    let resolver: BuildSettingResolver
    let compilerType: CompilerType

    private func targetCompilerArguments() -> [String] {
        var args: [String] = []
        for mapping in ResolverProvider.mappings {
            guard mapping.appliesTo.contains(compilerType) else { continue }
            if let value = resolver.resolve(forKey: mapping.buildSetting) {
                args += mapping.transform(value)
            }
        }
        return args
    }

    public func arguments(
        for fileURL: URL,
        compilerType: CompilerType
    ) -> [String] {
        var args = targetCompilerArguments()

        if let fileFlags = resolver.resolveFileCompilerFlags(for: fileURL) {
            args += fileFlags
            args.append(fileURL.path)
        }
        return args
    }
}

extension ResolverProvider {
    static let commonMappings: [CompilerFlagMapping] = [
        CompilerFlagMapping(
            buildSetting: "SDKROOT",
            appliesTo: [.swift]
        ) { ["-sdk", $0] },
        CompilerFlagMapping(
            buildSetting: "SDKROOT",
            appliesTo: [.clang]
        ) { ["-isysroot", $0] },
        CompilerFlagMapping(
            buildSetting: "ARCHS",
            appliesTo: [.swift, .clang]
        ) { $0.split(separator: " ").map { [
            "-arch",
            String($0)
        ] }.flatMap(\.self) },
        CompilerFlagMapping(
            buildSetting: "HEADER_SEARCH_PATHS",
            appliesTo: [.swift, .clang]
        ) { $0.split(separator: " ").map { [
            "-I",
            String($0)
        ] }.flatMap(\.self) },
        CompilerFlagMapping(
            buildSetting: "FRAMEWORK_SEARCH_PATHS",
            appliesTo: [.swift, .clang]
        ) { $0.split(separator: " ").map { [
            "-F",
            String($0)
        ] }.flatMap(\.self) },
        CompilerFlagMapping(
            buildSetting: "LIBRARY_SEARCH_PATHS",
            appliesTo: [.clang]
        ) { $0.split(separator: " ").map { [
            "-L",
            String($0)
        ] }.flatMap(\.self) }
    ]

    static let swiftMappings: [CompilerFlagMapping] = [
        CompilerFlagMapping(
            buildSetting: "PRODUCT_MODULE_NAME",
            appliesTo: [.swift]
        ) { ["-module-name", $0] },
        CompilerFlagMapping(
            buildSetting: "SWIFT_VERSION",
            appliesTo: [.swift]
        ) { ["-swift-version", $0] },
        CompilerFlagMapping(
            buildSetting: "SWIFT_OPTIMIZATION_LEVEL",
            appliesTo: [.swift]
        ) { optLevel in
            var flags = [optLevel]
            if optLevel == "-Onone" {
                flags.append("-enforce-exclusivity=checked")
            } else {
                flags.append("-enforce-exclusivity=unchecked")
            }
            return flags
        },
        CompilerFlagMapping(
            buildSetting: "SWIFT_ACTIVE_COMPILATION_CONDITIONS",
            appliesTo: [.swift]
        ) { $0.split(separator: " ").map { [
            "-D",
            String($0)
        ] }.flatMap(\.self) },
        CompilerFlagMapping(
            buildSetting: "ENABLE_TESTABILITY",
            appliesTo: [.swift]
        ) { $0 == "YES" ? ["-enable-testing"] : [] },
        CompilerFlagMapping(
            buildSetting: "OTHER_SWIFT_FLAGS",
            appliesTo: [.swift]
        ) { $0.split(separator: " ").map { String($0) } }
    ]

    static let clangMappings: [CompilerFlagMapping] = [
        CompilerFlagMapping(
            buildSetting: "GCC_PREPROCESSOR_DEFINITIONS",
            appliesTo: [.clang]
        ) { $0.split(separator: " ").map { [
            "-D",
            String($0)
        ] }.flatMap(\.self) },
        CompilerFlagMapping(
            buildSetting: "CLANG_CXX_LANGUAGE_STANDARD",
            appliesTo: [.clang]
        ) { ["-std=\($0)"] },
        CompilerFlagMapping(
            buildSetting: "CLANG_CXX_LIBRARY",
            appliesTo: [.clang]
        ) { ["-stdlib=\($0)"] },
        CompilerFlagMapping(
            buildSetting: "CLANG_ENABLE_MODULES",
            appliesTo: [.clang]
        ) { $0 == "YES" ? ["-fmodules"] : [] },
        CompilerFlagMapping(
            buildSetting: "CLANG_ENABLE_OBJC_ARC",
            appliesTo: [.clang]
        ) { $0 == "YES" ? ["-fobjc-arc"] : [] },
        CompilerFlagMapping(
            buildSetting: "DEBUG_INFORMATION_FORMAT",
            appliesTo: [.clang]
        ) { $0 == "dwarf" ? ["-g"] : [] },
        CompilerFlagMapping(
            buildSetting: "OTHER_CFLAGS",
            appliesTo: [.clang]
        ) { $0.split(separator: " ").map { String($0) }
        },
        CompilerFlagMapping(
            buildSetting: "OTHER_CPLUSPLUSFLAGS",
            appliesTo: [.clang]
        ) { $0.split(separator: " ").map { String($0) } }
    ]

    static var mappings: [CompilerFlagMapping] {
        commonMappings + swiftMappings + clangMappings
    }
}

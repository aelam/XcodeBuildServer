import Foundation

struct ClangProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .clang, let fileURL = context.fileURL else { return [] }
        return buildFlags(
            settings: context.buildSettings,
            fileURL: fileURL,
            languageDialect: context.languageDialect
        )
    }

    private func buildFlags(
        settings: [String: String],
        fileURL: URL,
        languageDialect: XcodeLanguageDialect
    ) -> [String] {
        var flags: [String] = []

        flags.append(contentsOf: buildLangFlag(for: languageDialect))
        flags.append(fileURL.path)
        flags.append(contentsOf: ["-Xclang", "-fallow-pch-with-compiler-errors"])
        flags.append(contentsOf: buildPrecompiledHeaderFlags(settings: settings))
        flags.append(contentsOf: buildPreprocessorFlags(settings: settings))
        flags.append(contentsOf: buildOtherFlags(settings: settings))
        flags.append(contentsOf: buildOptimizationFlags(settings: settings))

        return flags
    }

    private func buildLangFlag(for dialect: XcodeLanguageDialect) -> [String] {
        switch dialect {
        case .c:
            ["-x", "c"]
        case .cpp:
            ["-x", "c++"]
        case .objc:
            ["-x", "objective-c"]
        case .objcCpp:
            ["-x", "objective-c++"]
        default:
            []
        }
    }

    private func buildPrecompiledHeaderFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if let pchFile = settings["GCC_PRECOMPILE_HEADER"] {
            flags.append("-include")
            flags.append(pchFile)
        }

        return flags
    }

    private func buildPreprocessorFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if let defs = settings["GCC_PREPROCESSOR_DEFINITIONS"] {
            for def in defs.split(separator: " ") {
                flags.append("-D\(def)")
            }
        }

        return flags
    }

    private func buildOptimizationFlags(settings: [String: String]) -> [String] {
        let optimizationMapFlags = [
            "0": "-O0",
            "1": "-O1",
            "2": "-O2",
            "3": "-O3",
            "s": "-Os",
            "fast": "-Ofast"
        ]

        var flags: [String] = []

        if let optimizationLevel = settings["GCC_OPTIMIZATION_LEVEL"] {
            flags.append(optimizationMapFlags[optimizationLevel] ?? optimizationLevel)
        }

        return flags
    }

    private func buildOtherFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if let otherCFlags = settings["OTHER_CFLAGS"] {
            flags.append(contentsOf: otherCFlags.split(separator: " ").map { String($0) })
        }

        if let otherCppFlags = settings["OTHER_CPLUSPLUSFLAGS"] {
            flags.append(contentsOf: otherCppFlags.split(separator: " ").map { String($0) })
        }

        return flags
    }
}

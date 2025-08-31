import Foundation

struct ClangProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .clang else { return [] }
        return buildFlags(settings: context.buildSettings, languageDialect: context.languageDialect)
    }

    private func buildFlags(settings: [String: String], languageDialect: XcodeLanguageDialect) -> [String] {
        var flags: [String] = []

        flags.append("-c")
        flags.append("-j14") //

        flags.append("-fallow-pch-with-compiler-errors")
        flags.append(contentsOf: buildLangFlag(for: languageDialect))
        flags.append(contentsOf: buildPrecompiledHeaderFlags(settings: settings))

        if let optimizationLevel = settings["GCC_OPTIMIZATION_LEVEL"] {
            flags.append(optimizationLevel)
        }

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
}

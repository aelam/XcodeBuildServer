import Foundation

struct ClangWarningProvider: CompileArgProvider, Sendable {
    private let clangWarnMap: [String: String] = [
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "-Wblock-capture-autoreleasing",
        "CLANG_WARN_BOOL_CONVERSION": "-Wbool-conversion",
        "CLANG_WARN_COMMA": "-Wcomma",
        "CLANG_WARN_CONSTANT_CONVERSION": "-Wconstant-conversion",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "-Wdeprecated-objc-implementations",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "-Wdirect-objc-isa-usage",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "-Wdocumentation-comments",
        "CLANG_WARN_EMPTY_BODY": "-Wempty-body",
        "CLANG_WARN_ENUM_CONVERSION": "-Wenum-conversion",
        "CLANG_WARN_INFINITE_RECURSION": "-Winfinite-recursion",
        "CLANG_WARN_INT_CONVERSION": "-Wint-conversion",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "-Wnon-literal-null-conversion",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "-Wobjc-implicit-retain-self",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "-Wobjc-literal-conversion",
        "CLANG_WARN_OBJC_ROOT_CLASS": "-Wobjc-root-class",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "-Wquoted-include-in-framework-header",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "-Wrange-loop-analysis",
        "CLANG_WARN_STRICT_PROTOTYPES": "-Wstrict-prototypes",
        "CLANG_WARN_SUSPICIOUS_MOVE": "-Wsuspicious-move",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "-Wunguarded-availability",
        "CLANG_WARN_UNREACHABLE_CODE": "-Wunreachable-code",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "-Wduplicate-method-match"
    ]

    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .clang else { return [] }
        return buildClangFlags(settings: context.buildSettings)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func buildClangFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        // Add user-configured Clang flags from build settings
        if let std = settings["CLANG_CXX_LANGUAGE_STANDARD"] {
            flags.append("-std=\(std)")
        }
        if let std = settings["GCC_C_LANGUAGE_STANDARD"] {
            flags.append("-std=\(std)") // e.g., "gnu11"
        }
        if settings["CLANG_ENABLE_MODULES"] == "YES" {
            flags.append("-fmodules")
        }
        if settings["CLANG_ENABLE_OBJC_ARC"] == "YES" {
            flags.append("-fobjc-arc")
        }
        if settings["CLANG_ENABLE_OBJC_WEAK"] == "YES" {
            flags.append("-fobjc-weak")
        }

        for (key, flag) in clangWarnMap {
            if settings[key] == "YES" {
                flags.append(flag)
            }
        }

        return flags
    }
}

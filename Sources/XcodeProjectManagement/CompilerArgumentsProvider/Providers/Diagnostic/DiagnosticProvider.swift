import Foundation

struct DiagnosticProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        switch context.compiler {
        case .swift:
            buildSwiftFlags(settings: context.buildSettings)
        case .clang:
            buildClangFlags(settings: context.buildSettings)
        }
    }

    private func buildSwiftFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        flags.append("-Xfrontend")
        flags.append("-debug-time-compilation")
        flags.append("-Xfrontend")
        flags.append("-debug-time-parse")
        flags.append("-Xfrontend")
        flags.append("-debug-time-type-check")
        flags.append("-Xfrontend")
        flags.append("-debug-time-closure-creation")

        return flags
    }

    private func buildClangFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        flags.append("-fmessage-length=0")
        flags.append("-fdiagnostics-show-template-hints")
        flags.append("-fdiagnostics-show-note-include-stack")
        flags.append("-fno-color-diagnostics")
        flags.append("-fmacro-backtrace-limit=0")
        flags.append("-fsyntax-only")
        flags.append("-detailed-preprocessing-record")

        return flags
    }
}

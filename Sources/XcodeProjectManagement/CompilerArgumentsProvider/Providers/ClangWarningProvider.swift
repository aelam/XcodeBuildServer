import Foundation

struct ClangWarningProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .clang else { return [] }
        return ["-Werror", "-Wclang-diagnostic", "-fsyntax-only", context.fileURL?.path ?? ""]
    }
}

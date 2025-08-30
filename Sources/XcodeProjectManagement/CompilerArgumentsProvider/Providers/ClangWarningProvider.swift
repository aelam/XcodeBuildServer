import Foundation

struct ClangWarningProvider: CompileArgProvider, Sendable {
    func arguments(for fileURL: URL, compilerType: CompilerType) -> [String] {
        guard compilerType == .clang else { return [] }
        return ["-Werror", "-Wclang-diagnostic", "-fsyntax-only", fileURL.path]
    }
}

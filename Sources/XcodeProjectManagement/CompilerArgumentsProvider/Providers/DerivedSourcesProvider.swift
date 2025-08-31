import Foundation

struct DerivedSourcesProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        ["-I", "A"]
    }
}

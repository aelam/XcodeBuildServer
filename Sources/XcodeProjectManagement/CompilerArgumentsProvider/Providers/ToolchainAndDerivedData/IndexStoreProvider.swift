import Foundation

struct IndexStoreProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        let indexStorePath = context.derivedDataPath
            .deletingLastPathComponent()
            .appendingPathComponent("Index.noindex/DataStore")
        return ["-index-store-path", indexStorePath.path]
    }
}

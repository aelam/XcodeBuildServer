import Foundation

struct IndexStoreProvider: CompileArgProvider, Sendable {
    let derivedDataPath: URL

    func arguments(for fileURL: URL, compilerType: CompilerType) -> [String] {
        [
            "-index-store-path",
            derivedDataPath.appendingPathComponent("Index").path
        ]
    }
}

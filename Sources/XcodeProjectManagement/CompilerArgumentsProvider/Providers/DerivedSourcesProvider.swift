import Foundation

struct DerivedSourcesProvider: CompileArgProvider, Sendable {
    let derivedDataPath: URL

    func arguments(for fileURL: URL, compilerType: CompilerType) -> [String] {
        []
    }
}

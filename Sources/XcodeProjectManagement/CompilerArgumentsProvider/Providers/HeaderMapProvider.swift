import Foundation

struct HeaderMapProvider: CompileArgProvider, Sendable {
    let derivedDataPath: URL

    func arguments(for fileURL: URL, compilerType: CompilerType) -> [String] {
        ["-hmap", derivedDataPath.appendingPathComponent("ModuleCache").path]
    }
}

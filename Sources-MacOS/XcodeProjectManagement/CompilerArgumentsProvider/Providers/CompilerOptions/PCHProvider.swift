import Foundation

struct PCHProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .clang else { return [] }
        return buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if let sourceRoot = settings["SRCROOT"],
           let pchOutputPath = settings["SHARED_PRECOMPS_DIR"] {
            let path = sourceRoot + "/" + pchOutputPath
            flags.append(contentsOf: ["-pch-output-dir", path])
        }
        return flags
    }
}

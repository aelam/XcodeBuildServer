import Foundation

struct HeaderSearchPathProvider: CompileArgProvider, Sendable {
    private let searchPathsKeys = [
        "HEADER_SEARCH_PATHS",
        "CONFIGURATION_BUILD_DIR"
    ]

    func arguments(for context: ArgContext) -> [String] {
        buildHeaderSearchPathsFlags(settings: context.buildSettings, compiler: context.compiler)
    }

    private func buildHeaderSearchPathsFlags(settings: [String: String], compiler: CompilerType) -> [String] {
        var flags: [String] = []

        for pathsKey in searchPathsKeys {
            guard let paths = settings[pathsKey] else { continue }
            flags.append(contentsOf: buildFlags(paths: paths, compiler: compiler))
        }

        return flags
    }

    private func buildFlags(paths: String, compiler: CompilerType) -> [String] {
        let headerSearchPaths = paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }

        if compiler == .swift {
            return headerSearchPaths.flatMap { ["-Xcc", "-I\($0)"] }
        } else {
            return headerSearchPaths.flatMap { ["-I\($0)"] }
        }
    }
}

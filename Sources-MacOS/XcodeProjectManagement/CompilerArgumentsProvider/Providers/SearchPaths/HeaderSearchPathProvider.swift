import Foundation

struct HeaderSearchPathProvider: CompileArgProvider, Sendable {
    private let searchPathsKeys = [
        "HEADER_SEARCH_PATHS",
        "CONFIGURATION_BUILD_DIR",
        "SWIFT_INCLUDE_PATHS"
    ]

    func arguments(for context: ArgContext) -> [String] {
        buildHeaderSearchPathsFlags(settings: context.buildSettings, compiler: context.compiler)
    }

    private func buildHeaderSearchPathsFlags(settings: [String: String], compiler: CompilerType) -> [String] {
        searchPathsKeys.compactMap { settings[$0] }
            .flatMap { buildFlags(paths: $0, compiler: compiler) }
    }

    private func buildFlags(paths: String, compiler: CompilerType) -> [String] {
        let headerSearchPaths = paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }

        if compiler == .swift {
            return headerSearchPaths.flatMap { ["-Xcc", "-I\($0)", "-I\($0)"] }
        } else {
            return headerSearchPaths.flatMap { ["-I\($0)"] }
        }
    }
}

import Foundation

struct HeaderSearchPathProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings, compiler: context.compiler)
    }

    private func buildFlags(settings: [String: String], compiler: CompilerType) -> [String] {
        guard let paths = settings["HEADER_SEARCH_PATHS"] else { return [] }

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

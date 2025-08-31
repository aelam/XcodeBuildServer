import Foundation

struct FrameworkSearchPathProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        guard let paths = settings["FRAMEWORK_SEARCH_PATHS"] else { return [] }

        return paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .map { "-F\($0)" }
    }
}

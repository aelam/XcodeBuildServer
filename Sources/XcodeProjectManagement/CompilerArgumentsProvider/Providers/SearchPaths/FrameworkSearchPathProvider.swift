import Foundation

struct FrameworkSearchPathProvider: CompileArgProvider, Sendable {
    private let frameworkSearchPathKeys: [String] = [
        "FRAMEWORK_SEARCH_PATHS",
        "OTHER_FRAMEWORK_SEARCH_PATHS",
        "CONFIGURATION_BUILD_DIR"
    ]

    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        frameworkSearchPathKeys
            .compactMap { settings[$0] }
            .flatMap { buildFlags(for: $0) }
    }

    private func buildFlags(for paths: String) -> [String] {
        paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .map { "-F\($0)" }
    }
}

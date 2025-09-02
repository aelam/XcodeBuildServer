import Foundation

struct FrameworkSearchPathProvider: CompileArgProvider, Sendable {
    private let frameworkSearchPathKeys: [String] = [
        "FRAMEWORK_SEARCH_PATHS",
        "OTHER_FRAMEWORK_SEARCH_PATHS",
        "CONFIGURATION_BUILD_DIR"
    ]

    func arguments(for context: ArgContext) -> [String] {
        buildFlagsForFrameworkSearch(settings: context.buildSettings) +
            buildFlagsForSwiftPM(settings: context.buildSettings)
    }

    private func buildFlagsForFrameworkSearch(settings: [String: String]) -> [String] {
        frameworkSearchPathKeys
            .compactMap { settings[$0] }
            .flatMap { buildFlags(for: $0) }
    }

    // XcodeProject with SwiftPM frameworks
    private func buildFlagsForSwiftPM(settings: [String: String]) -> [String] {
        guard let configurationBuildDir = settings["CONFIGURATION_BUILD_DIR"] else {
            return []
        }
        let packageFrameworkURLs = URL(fileURLWithPath: configurationBuildDir)
            .appendingPathComponent("PackageFrameworks").path
        return buildFlags(for: packageFrameworkURLs)
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

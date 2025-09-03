import Foundation

struct FrameworkSearchPathProvider: CompileArgProvider, Sendable {
    private let frameworkSearchPathKeys: [String] = [
        "FRAMEWORK_SEARCH_PATHS",
        "OTHER_FRAMEWORK_SEARCH_PATHS",
        "CONFIGURATION_BUILD_DIR"
    ]

    func arguments(for context: ArgContext) -> [String] {
        buildFlagsForFrameworkSearch(settings: context.buildSettings, compiler: context.compiler) +
            buildFlagsForSwiftPM(settings: context.buildSettings, compiler: context.compiler)
    }

    private func buildFlagsForFrameworkSearch(settings: [String: String], compiler: CompilerType) -> [String] {
        frameworkSearchPathKeys
            .compactMap { settings[$0] }
            .flatMap { buildFlags(for: $0, compiler: compiler) }
    }

    // XcodeProject with SwiftPM frameworks
    private func buildFlagsForSwiftPM(settings: [String: String], compiler: CompilerType) -> [String] {
        guard let configurationBuildDir = settings["CONFIGURATION_BUILD_DIR"] else {
            return []
        }
        let packageFrameworkURLs = URL(fileURLWithPath: configurationBuildDir)
            .appendingPathComponent("PackageFrameworks").path
        return buildFlags(for: packageFrameworkURLs, compiler: compiler)
    }

    private func buildFlags(for paths: String, compiler: CompilerType) -> [String] {
        paths.components(separatedBy: " ")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
            .flatMap {
                if compiler == .swift {
                    ["-F\($0)", "-Xcc", "-F\($0)"]
                } else {
                    ["-F\($0)"]
                }
            }
    }
}

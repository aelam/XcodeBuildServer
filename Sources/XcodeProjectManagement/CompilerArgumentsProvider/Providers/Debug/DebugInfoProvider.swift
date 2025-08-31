import Foundation

struct DebugInfoProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []
        flags.append("-g")
        flags.append("-gmodules")

        return flags
    }
}

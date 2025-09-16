import Foundation

struct DebugInfoProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings, compiler: context.compiler)
    }

    private func buildFlags(settings: [String: String], compiler: CompilerType) -> [String] {
        var flags: [String] = []
        flags.append("-g")

        if compiler == .swift {
            flags.append(contentsOf: ["-Xfrontend", "-serialize-debugging-options"])
        } else {
            flags.append("-gmodules")
        }
        return flags
    }
}

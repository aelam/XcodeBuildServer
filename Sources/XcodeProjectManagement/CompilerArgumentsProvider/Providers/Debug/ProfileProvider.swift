import Foundation

struct ProfileProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings, compiler: context.compiler)
    }

    private func buildFlags(settings: [String: String], compiler: CompilerType) -> [String] {
        var flags: [String] = []

        if compiler == .swift {
            // Coverage
            flags.append(contentsOf: ["-profile-coverage-mapping", "-profile-generate"])
        } else {
            flags.append(contentsOf: ["-fprofile-instr-generate", "-fcoverage-mapping"])
        }

        return flags
    }
}

import Foundation

struct SwiftProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .swift else { return [] }
        return buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if let std = settings["SWIFT_VERSION"] {
            flags.append("-swift-version \(std)")
        }

        return flags
    }
}

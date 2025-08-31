import Foundation

struct ObjectiveCFeaturesProvider: CompileArgProvider, Sendable {
    private let flagMap = [
        "CLANG_ENABLE_OBJC_ARC": "-fobjc-arc",
        "CLANG_ENABLE_OBJC_WEAK": "-fobjc-weak"
    ]

    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        for (key, flag) in flagMap where settings[key] == "YES" {
            flags.append(flag)
        }
        return flags
    }
}

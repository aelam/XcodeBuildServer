import Foundation

struct SwiftProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .swift else { return [] }
        return buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if let sourceRoot = settings["SRCROOT"],
           let bridgingHeader = settings["SWIFT_OBJC_BRIDGING_HEADER"] {
            let path = sourceRoot + "/" + bridgingHeader
            flags.append("-include")
            flags.append(path) // objc bridging header full path
        }

        flags.append("-enable-batch-mode") // swift only

        if let optimizationLevel = settings["SWIFT_OPTIMIZATION_LEVEL"] {
            flags.append(optimizationLevel)
        }

        flags.append("-emit-const-values")

        if
            let configurationTempDir = settings["CONFIGURATION_TEMP_DIR"],
            let targetName = settings["TARGET_NAME"],
            let arch = settings["ARCH"] {
            let fileURL = URL(fileURLWithPath: configurationTempDir)
                .appendingPathComponent("Objects-normal")
                .appendingPathComponent(arch)
                .appendingPathComponent("\(targetName)_const_extract_protocols.json")
            flags.append(contentsOf: [
                "-Xfrontend",
                "-const-gather-protocols-file",
                "-Xfrontend",
                fileURL.path
            ])
        }
        return flags
    }
}

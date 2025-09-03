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
            flags.append("-import-objc-header")
            flags.append(path) // objc bridging header full path
        }

        flags.append("-c")
        flags.append("-j14") //
        flags.append("-enable-batch-mode") // swift only
        flags.append("-enable-bare-slash-regex")
        flags.append(contentsOf: ["-enable-experimental-feature", "DebugDescriptionMacro"])
        flags.append("-suppress-warnings")

        if let optimizationLevel = settings["SWIFT_OPTIMIZATION_LEVEL"] {
            flags.append(optimizationLevel)

            if optimizationLevel == "-Onone" {
                flags.append("-enforce-exclusivity=checked")
            }
        }

        if settings["ENABLE_TESTABILITY"] == "YES" {
            flags.append("-enable-testing")
        }

        flags.append(contentsOf: buildEmitConstValueFlags(settings: settings))
        flags.append(contentsOf: buildProtocolFileFlags(settings: settings))

        // OTHER_SWIFT_FLAGS
        if let otherSwiftFlags = settings["OTHER_SWIFT_FLAGS"] {
            let otherFlags = otherSwiftFlags
                .components(separatedBy: " ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            flags.append(contentsOf: otherFlags)
        }

        return flags
    }

    private func buildEmitConstValueFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []
        // -emit-const-values-path <DerivedData>/Build/Products/<config>-<platform>/<Target>.swiftconstvalues
        guard
            let configurationTempDir = settings["CONFIGURATION_TEMP_DIR"],
            let targetName = settings["TARGET_NAME"],
            let arch = settings["NATIVE_ARCH"] else {
            return []
        }
        let fileURL = URL(fileURLWithPath: configurationTempDir)
            .appendingPathComponent("Objects-normal")
            .appendingPathComponent(arch)
            .appendingPathComponent("\(targetName).swiftconstvalues")
        flags.append(contentsOf: [
            "-emit-const-values",
            "-emit-const-values-path",
            fileURL.path
        ])
        return flags
    }

    private func buildProtocolFileFlags(settings: [String: String]) -> [String] {
        var flags: [String] = []

        if
            let configurationTempDir = settings["CONFIGURATION_TEMP_DIR"],
            let targetName = settings["TARGET_NAME"],
            let arch = settings["NATIVE_ARCH"] {
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

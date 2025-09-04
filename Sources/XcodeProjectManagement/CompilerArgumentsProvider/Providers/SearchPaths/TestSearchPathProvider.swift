import Foundation

//   "TEST_FRAMEWORK_SEARCH_PATHS" : "
//   /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator18.5.sdk/Developer/Library/Frameworks",
//   "TEST_HOST" : "/Users/wang.lun/Desktop/HelloWorkspace/build/Release-iphonesimulator/Hello.app//Hello",
//   "TEST_LIBRARY_SEARCH_PATHS" : "
//   /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/lib",

struct TestSearchPathProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFrameworkFlags(settings: context.buildSettings) +
            buildPluginFlags(settings: context.buildSettings)
    }

    private func isTestTarget(settings: [String: String]) -> Bool {
        guard
            let productType = settings["PRODUCT_TYPE"],
            let xcodeProductType = XcodeProductType(rawValue: productType)
        else { return false }

        return xcodeProductType.isTestBundle
    }

    private func buildFrameworkFlags(settings: [String: String]) -> [String] {
        guard
            isTestTarget(settings: settings),
            let sdkRoot = settings["SDKROOT_PATH"],
            let sdkURL = URL(string: sdkRoot)
        else { return [] }

        let platformPath = sdkURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        return [
            // TEST_FRAMEWORK_SEARCH_PATHS
            "-F", platformPath.appendingPathComponent("Developer/Library/Frameworks").path,
            // TEST_LIBRARY_SEARCH_PATHS
            "-I", platformPath.appendingPathComponent("Developer/usr/lib").path
        ]
    }

    private func buildPluginFlags(settings: [String: String]) -> [String] {
        guard
            isTestTarget(settings: settings),
            let toolchainDir = settings["TOOLCHAIN_DIR"],
            let toolchainURL = URL(string: toolchainDir)
        else { return [] }

        // "-plugin-path",
        // "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing",
        let pluginPath = toolchainURL
            .appendingPathComponent("usr/lib/swift/host/plugins/testing")
        guard FileManager.default.fileExists(atPath: pluginPath.path) else {
            return []
        }

        return [
            "-plugin-path", pluginPath.path
        ]
    }
}

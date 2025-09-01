import Foundation

//   "TEST_FRAMEWORK_SEARCH_PATHS" : "
//   /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator18.5.sdk/Developer/Library/Frameworks",
//   "TEST_HOST" : "/Users/wang.lun/Desktop/HelloWorkspace/build/Release-iphonesimulator/Hello.app//Hello",
//   "TEST_LIBRARY_SEARCH_PATHS" : "
//   /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/lib",

struct TestSearchPathProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        guard let sdkRoot = settings["SDK_ROOT"] else { return [] }
        return [
            "-F", "\(sdkRoot)/Developer/Library/Frameworks", // TEST_FRAMEWORK_SEARCH_PATHS
            "-L", "\(sdkRoot)/Developer/usr/lib" // TEST_LIBRARY_SEARCH_PATHS
        ]
    }
}

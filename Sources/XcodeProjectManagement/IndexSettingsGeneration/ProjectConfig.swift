import Foundation

// MARK: - Enhanced Project Configuration

struct ProjectConfig {
    let rootURL: String
    let derivedDataPath: URL
    let indexStorePath: String
    let moduleCachePath: String

    init(primaryBuildSettings: XcodeProjectPrimaryBuildSettings, rootURL: URL) {
        self.rootURL = rootURL.path
        self.derivedDataPath = primaryBuildSettings.derivedDataPath
        self.indexStorePath = primaryBuildSettings.indexStoreURL.path
        self.moduleCachePath = derivedDataPath.deletingLastPathComponent()
            .appendingPathComponent("ModuleCache.noindex")
            .path
    }
}

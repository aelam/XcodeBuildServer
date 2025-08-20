import Foundation

// MARK: - Enhanced Project Configuration

struct ProjectConfig {
    let rootURL: String
    let derivedDataPath: URL
    let indexStorePath: String
    let moduleCachePath: String

    init(projectBuildSettings: XcodeProjectProjectBuildSettings, rootURL: URL) {
        self.rootURL = rootURL.path
        self.derivedDataPath = projectBuildSettings.derivedDataPath
        self.indexStorePath = projectBuildSettings.indexStoreURL.path
        self.moduleCachePath = derivedDataPath.deletingLastPathComponent()
            .appendingPathComponent("ModuleCache.noindex")
            .path
    }
}

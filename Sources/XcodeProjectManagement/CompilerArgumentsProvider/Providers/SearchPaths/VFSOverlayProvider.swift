import Foundation

struct VFSOverlayProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .swift else { return [] }
        return buildFlags(settings: context.buildSettings)
    }

    private func buildFlags(settings: [String: String]) -> [String] {
        guard
            let configurationTempDir = settings["CONFIGURATION_TEMP_DIR"],
            let configurationBuildDirURL = URL(string: configurationTempDir),
            let moduleName = settings["PRODUCT_MODULE_NAME"],
            let projectGUID = settings["PROJECT_GUID"],
            let platformName = settings["PLATFORM_NAME"]
        else {
            return []
        }
        let vfsoverlayPath = configurationBuildDirURL
            .appendingPathComponent("\(moduleName)-\(projectGUID)-VFS-\(platformName)")
            .appendingPathComponent("all-product-headers.yaml")

        return [
            "-Xcc", "-ivfsoverlay", "-Xcc", vfsoverlayPath.path
        ]
    }
}

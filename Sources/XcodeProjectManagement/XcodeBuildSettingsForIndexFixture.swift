enum XcodeBuildSettingsForIndexFixture {
    struct ProjectBuildSettings: Sendable {
        let target: String
        let configuration: String
        let sdk: String
        let derivedDataPath: String

        let SYMROOT: String
        let OBJROOT: String
        let BUILD_DIR: String // swiftlint:disable:this identifier_name
    }

    func fix(
        buildSettingsForIndex: XcodeBuildSettingsForIndex,
        projectBuildSettings: ProjectBuildSettings
    ) -> XcodeBuildSettingsForIndex {
        // Fix the build settings by ensuring all paths are absolute
        // var fixedSettings = buildSettingsForIndex
        // for (key, value) in fixedSettings {
        //     fixedSettings[key] = value.absolutePath
        // }
        // fixedSettings
        buildSettingsForIndex
    }
}

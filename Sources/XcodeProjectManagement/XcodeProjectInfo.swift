import Foundation

public struct XcodeProjectInfo: Sendable, Codable {
    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
    public let buildSettingsList: [XcodeBuildSettings]
    public let primaryBuildSettings: XcodeProjectPrimaryBuildSettings
    public let targets: [XcodeTarget]
    public let schemes: [XcodeScheme]
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL
    public let buildSettingsForIndex: XcodeBuildSettingsForIndex

    public init(
        rootURL: URL,
        projectLocation: XcodeProjectLocation,
        buildSettingsList: [XcodeBuildSettings],
        primaryBuildSettings: XcodeProjectPrimaryBuildSettings,
        targets: [XcodeTarget] = [],
        schemes: [XcodeScheme] = [],
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL,
        buildSettingsForIndex: XcodeBuildSettingsForIndex
    ) {
        self.rootURL = rootURL
        self.projectLocation = projectLocation
        self.buildSettingsList = buildSettingsList
        self.primaryBuildSettings = primaryBuildSettings
        self.targets = targets
        self.schemes = schemes
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.buildSettingsForIndex = buildSettingsForIndex
    }

    public var workspaceURL: URL {
        switch projectLocation {
        case let .explicitWorkspace(url), let .implicitWorkspace(_, url), let .standaloneProject(url):
            url
        }
    }

    public var name: String {
        switch projectLocation {
        case let .explicitWorkspace(url), let .implicitWorkspace(url, _), let .standaloneProject(url):
            url.lastPathComponent
        }
    }
}

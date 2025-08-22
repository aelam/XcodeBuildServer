import Foundation

public struct XcodeProjectInfo: Sendable, Codable {
    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
    public let buildSettingsList: [XcodeBuildSettings]
    public let xcodeProjectBuildSettings: XcodeProjectProjectBuildSettings
    public let importantScheme: XcodeScheme
    public let xcodeTargets: [XcodeTarget]
    public let schemes: [XcodeScheme]
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL
    public let xcodeBuildSettingsForIndex: XcodeBuildSettingsForIndex

    public init(
        rootURL: URL,
        projectLocation: XcodeProjectLocation,
        buildSettingsList: [XcodeBuildSettings],
        projectBuildSettings: XcodeProjectProjectBuildSettings,
        importantScheme: XcodeScheme,
        xcodeTargets: [XcodeTarget] = [],
        schemes: [XcodeScheme] = [],
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL,
        xcodeBuildSettingsForIndex: XcodeBuildSettingsForIndex
    ) {
        self.rootURL = rootURL
        self.projectLocation = projectLocation
        self.buildSettingsList = buildSettingsList
        self.xcodeProjectBuildSettings = projectBuildSettings
        self.importantScheme = importantScheme
        self.xcodeTargets = xcodeTargets
        self.schemes = schemes
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.xcodeBuildSettingsForIndex = xcodeBuildSettingsForIndex
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

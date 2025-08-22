import Foundation

public struct XcodeProjectBaseInfo: Sendable, Codable {
    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
    public let importantScheme: XcodeScheme
    public let xcodeTargets: [XcodeTarget]
    public let schemes: [XcodeScheme]
}

public struct XcodeProjectInfo: Sendable, Codable {
    public let baseProjectInfo: XcodeProjectBaseInfo
    public let buildSettingsList: [XcodeBuildSettings]
    public let xcodeProjectBuildSettings: XcodeProjectProjectBuildSettings
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL
    public let xcodeBuildSettingsForIndex: XcodeBuildSettingsForIndex

    public init(
        baseProjectInfo: XcodeProjectBaseInfo,
        buildSettingsList: [XcodeBuildSettings],
        projectBuildSettings: XcodeProjectProjectBuildSettings,
        derivedDataPath: URL,
        indexStoreURL: URL,
        indexDatabaseURL: URL,
        xcodeBuildSettingsForIndex: XcodeBuildSettingsForIndex
    ) {
        self.baseProjectInfo = baseProjectInfo
        self.buildSettingsList = buildSettingsList
        self.xcodeProjectBuildSettings = projectBuildSettings
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
        self.xcodeBuildSettingsForIndex = xcodeBuildSettingsForIndex
    }

    public var workspaceURL: URL {
        switch baseProjectInfo.projectLocation {
        case let .explicitWorkspace(url), let .implicitWorkspace(_, url), let .standaloneProject(url):
            url
        }
    }

    public var name: String {
        switch baseProjectInfo.projectLocation {
        case let .explicitWorkspace(url), let .implicitWorkspace(url, _), let .standaloneProject(url):
            url.lastPathComponent
        }
    }
}

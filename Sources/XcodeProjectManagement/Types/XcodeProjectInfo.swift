import Foundation

public struct XcodeProjectBaseInfo: Sendable, Codable {
    public let rootURL: URL
    public let projectLocation: XcodeProjectLocation
    public let xcodeProjectBuildSettings: XcodeProjectProjectBuildSettings
    public let importantScheme: XcodeScheme
    public let xcodeTargets: [XcodeTarget]
    public let schemes: [XcodeScheme]
    public var configuration = "Debug"
}

public struct XcodeProjectInfo: Sendable, Codable {
    public let baseProjectInfo: XcodeProjectBaseInfo
    public let buildSettingsList: [XcodeBuildSettings]
    public let xcodeBuildSettingsForIndex: XcodeBuildSettingsForIndex

    public init(
        baseProjectInfo: XcodeProjectBaseInfo,
        buildSettingsList: [XcodeBuildSettings],
        xcodeBuildSettingsForIndex: XcodeBuildSettingsForIndex
    ) {
        self.baseProjectInfo = baseProjectInfo
        self.buildSettingsList = buildSettingsList
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

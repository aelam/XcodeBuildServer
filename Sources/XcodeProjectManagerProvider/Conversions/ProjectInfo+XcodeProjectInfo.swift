//
//  ProjectInfo+XcodeProjectInfo.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import BuildServerProtocol
import Foundation
import XcodeProjectManagement

extension XcodeProjectInfo {
    func asProjectInfo() -> ProjectInfo {
        ProjectInfo(
            rootURL: baseProjectInfo.rootURL,
            name: name,
            targets: baseProjectInfo.xcodeTargets.map { $0.asProjectTarget() },
            buildSettingsForIndex: [:],
            projectBuildSettings: baseProjectInfo.xcodeGlobalSettings.asProjectBuildSettings()
        )
    }
}

extension XcodeTarget {
    func asProjectTarget() -> ProjectTarget {
        ProjectTarget(
            targetIndentifier: targetIdentifier,
            name: name,
            isSourcesResolved: false,
            isDependenciesResolved: false,
            sourceFiles: [],
            dependencies: [],
            productType: xcodeProductType.asProductType
        )
    }

    var targetIdentifier: String {
        "xcode://\(projectURL.path)/\(name)"
    }
}

extension XcodeGlobalSettings {
    func asProjectBuildSettings() -> ProjectBuildSettings {
        ProjectBuildSettings(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL,
            symRoot: symRoot,
            objRoot: objRoot,
            sdkStatCacheDir: sdkStatCacheDir,
            sdkStatCachePath: sdkStatCachePath
        )
    }
}

//
//  SourceFileInfo.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/09/04.
//

import Foundation
import XcodeProjectManagement

struct TargetInfo: Sendable {
    let projectFolder: URL
    let projectFilePath: String // relative to projectFolder
    let targetName: String
    let configurationName: String = "Debug"
    var derivedDataPath: URL {
        PathHash.derivedDataFullPath(for: projectFolder.appendingPathComponent(projectFilePath).path)
    }

    var projectFileFullPath: URL {
        let projectFilePath = (projectFilePath as NSString).expandingTildeInPath
        if projectFilePath.hasPrefix("/") {
            return URL(fileURLWithPath: projectFilePath)
        }
        return projectFolder.appendingPathComponent(projectFilePath)
    }
}

struct SourceFileInfo: Sendable {
    let targetInfo: TargetInfo
    let filePath: String // relative to projectFolder

    var fileFullPath: URL {
        let filePath = (filePath as NSString).expandingTildeInPath
        if filePath.hasPrefix("/") {
            return URL(fileURLWithPath: filePath)
        }
        return targetInfo.projectFolder.appendingPathComponent(filePath)
    }
}

extension TargetInfo {
    init(sharedOptions: SharedOptions) {
        self.init(
            projectFolder: URL(fileURLWithPath: sharedOptions.workspaceFolder),
            projectFilePath: sharedOptions.projectFilePath,
            targetName: sharedOptions.targetName
        )
    }
}

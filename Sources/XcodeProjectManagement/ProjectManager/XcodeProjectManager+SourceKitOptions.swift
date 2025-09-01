//
//  XcodeProjectManager+SourceKitOptions.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/09/01.
//

import Foundation

public extension XcodeProjectManager {
    func getCompileArguments(targetIdentifier: TargetIdentifier, sourceFileURL: URL) async throws -> [String] {
        let projectFilePath = targetIdentifier.projectFilePath
        let targetName = targetIdentifier.targetName

        guard
            let xcodeProjectBaseInfo,
            let projectURL = URL(string: projectFilePath),
            let xcodeProj = loadXcodeProjCache(projectURL: projectURL)
        else {
            return []
        }

        let sourceItems = SourceFileLister.loadSourceFiles(
            for: xcodeProj,
            targets: [targetName]
        )[targetIdentifier.rawValue] ?? []

        let generator = try CompileArgGenerator.create(
            xcodeInstallation: xcodeProjectBaseInfo.xcodeInstallation,
            xcodeGlobalSettings: xcodeProjectBaseInfo.xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: targetName,
            configurationName: xcodeProjectBaseInfo.configuration,
            fileURL: sourceFileURL,
            sourceItems: sourceItems
        )

        return generator.compileArguments()
    }
}

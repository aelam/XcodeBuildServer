//
//  BSPServerService+BuildTargetSources.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import BuildServerProtocol
import Foundation

extension BSPServerService {
    func getSourcesItems(targetIds: [BSPBuildTargetIdentifier]) async throws -> [SourcesItem] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project manager not initialized")
        }
        return try await projectManager.getSourceFileList(targetIdentifiers: targetIds)
    }
}

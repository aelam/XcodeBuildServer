//
//  BSPServerService+Initialize.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import Foundation

public extension BSPServerService {
    func initializeProject(rootURL: URL) async throws {
        if projectManager != nil {
            return
        }

        logger.info("Initializing project...")

        let projectManager = try await Task.detached {
            let projectManager = try await ProjectManagerProviderRegistry
                .createFactory().createProjectManager(
                    rootURL: rootURL
                )

            try await projectManager.initialize()
            return projectManager
        }.value
        logger.info("!!projectManager created: \(projectManager)")
        self.projectManager = projectManager
    }
}

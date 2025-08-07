//
//  BuildServerContext+BuildInitializeResponse.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/07.
//
import Foundation

public extension BuildServerContext {
    func getIndexStoreURL() async throws -> URL {
        let state = try loadedState
        guard let projectInfo = await state.projectManager.currentProjectInfo else {
            throw BuildServerError.invalidConfiguration("Project not loaded")
        }
        return projectInfo.indexStoreURL
    }

    func getIndexDatabaseURL() async throws -> URL {
        let state = try loadedState
        guard let projectInfo = await state.projectManager.currentProjectInfo else {
            throw BuildServerError.invalidConfiguration("Project not loaded")
        }
        return projectInfo.indexDatabaseURL
    }
}

//
//  BuildServerContext+BuildInitializeResponse.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/07.
//
import Foundation

public extension BuildServerContext {
    func getIndexStoreURL() async throws -> URL {
        try loadedState.xcodeProjectInfo.indexStoreURL
    }

    func getIndexDatabaseURL() async throws -> URL {
        try loadedState.xcodeProjectInfo.indexDatabaseURL
    }
}

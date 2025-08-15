//
//  BuildServerContext+BuildInitializeResponse.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/07.
//
import Foundation

public extension BuildServerContext {
    func getIndexStoreURL() throws -> URL {
        try loadedState.xcodeProjectInfo.indexStoreURL
    }

    func getIndexDatabaseURL() throws -> URL {
        try loadedState.xcodeProjectInfo.indexDatabaseURL
    }

    func getDerivedDataPath() throws -> URL {
        try loadedState.xcodeProjectInfo.derivedDataPath
    }
}

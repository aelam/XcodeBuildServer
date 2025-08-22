//
//  BSPServerService+SourceKitOptions.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//
import Foundation

public extension BSPServerService {
    /// 获取编译参数（BSP 协议适配）
    func getCompileArguments(targetIdentifier: BuildTargetIdentifier, fileURL: URL) async throws -> [String] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project not initialized")
        }

        logger.debug("Getting compile arguments for target: \(targetIdentifier.uri.stringValue), file: \(fileURL)")

        return try await projectManager.getCompileArguments(
            targetIdentifier: targetIdentifier.uri.stringValue,
            sourceFileURL: fileURL
        )
    }
}

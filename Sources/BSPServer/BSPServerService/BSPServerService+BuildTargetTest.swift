//  BSPServerService+BuildTargetRun.swift
import BuildServerProtocol
import Foundation

extension BSPServerService {
    func test(
        targetIdentifiers: [BSPBuildTargetIdentifier],
        arguments: [String]?, // e.g. ["-configuration", "Debug", "-destination", "id=XXXX"]
        environmentVariables: [String: String]?,
        workingDirectory: URI?,
    ) async throws -> StatusCode {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project not initialized")
        }

        return try await projectManager.test(
            targetIdentifiers: targetIdentifiers,
            arguments: arguments,
            environmentVariables: environmentVariables,
            workingDirectory: workingDirectory
        )
    }
}

//  BSPServerService+BuildTargetRun.swift
import BuildServerProtocol
import Foundation

extension BSPServerService {
    //

    private func run(
        targetIdentifier: BSPBuildTargetIdentifier,
        install: Bool
    ) async throws -> StatusCode {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project manager not initialized")
        }

        let taskManager = getTaskManager()

        return .cancelled
    }

    private func install(
        targetIdentifier: BSPBuildTargetIdentifier
    ) async throws -> StatusCode {
        try await run(targetIdentifier: targetIdentifier, install: true)
    }
}

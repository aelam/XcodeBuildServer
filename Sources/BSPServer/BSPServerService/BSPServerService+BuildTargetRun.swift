//  BSPServerService+BuildTargetRun.swift
import BuildServerProtocol
import Foundation

extension BSPServerService {
    //

    private func run(
        targetIdentifier: BSPBuildTargetIdentifier,
        install: Bool
    ) async throws -> StatusCode {
        // not implemented yet
        .error
    }

    private func install(
        targetIdentifier: BSPBuildTargetIdentifier
    ) async throws -> StatusCode {
        try await run(targetIdentifier: targetIdentifier, install: true)
    }
}

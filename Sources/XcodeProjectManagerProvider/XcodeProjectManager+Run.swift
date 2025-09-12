import BuildServerProtocol
import Foundation
import Logger
import PathKit
import XcodeProj
import XcodeProjectManagement

public extension XcodeProjectManager {
    func run(
        targetIdentifier: BSPBuildTargetIdentifier,
        arguments: [String]?, // e.g. ["-configuration", "Debug"]
        environmentVariables: [String: String]?,
        workingDirectory: URI?
    ) async throws -> StatusCode {
        let xcodeTargetIdentifier = XcodeTargetIdentifier(rawValue: targetIdentifier.uri.stringValue)

        let result = try await run(
            xcodeTargetIdentifier: xcodeTargetIdentifier,
            arguments: arguments,
            environmentVariables: environmentVariables,
            workingDirectory: workingDirectory?.fileURL
        )

        let statuCode: StatusCode = switch result.statusCode {
        case .success:
            .ok
        case .error:
            .error
        }

        return statuCode
    }
}

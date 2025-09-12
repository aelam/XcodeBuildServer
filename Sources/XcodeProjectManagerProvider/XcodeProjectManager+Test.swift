import BuildServerProtocol
import Foundation
import Logger
import PathKit
import XcodeProj
import XcodeProjectManagement

public extension XcodeProjectManager {
    func test(
        targetIdentifiers: [BSPBuildTargetIdentifier],
        arguments: [String]?, // e.g. ["-configuration", "Debug"]
        environmentVariables: [String: String]?,
        workingDirectory: URI?
    ) async -> StatusCode {
        let xcodeTargetIdentifiers = targetIdentifiers.map { XcodeTargetIdentifier(rawValue: $0.uri.stringValue) }

        let result = await test(
            xcodeTargetIdentifiers: xcodeTargetIdentifiers,
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

import Foundation
import Logger
import PathKit
import XcodeProj

enum XcodeRunError: Error {
    case appNotFound(String)
    case simulatorNotFound(String)
    case deviceNotFound(String)
    case failedToLaunchApp(String)
    case cancelled
}

extension XcodeProjectManager {
    func run(
        targetIdentifier: XcodeTargetIdentifier,
        isInstallRequired: Bool
    ) async throws -> XcodeRunError {
        // TODO: implement this method
        throw XcodeRunError.cancelled
    }
}

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
        guard let xcodeProjectBaseInfo else {
            throw NSError(
                domain: "XcodeProjectManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Xcode project not loaded"]
            )
        }

        return .cancelled
    }
}

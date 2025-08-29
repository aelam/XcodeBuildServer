import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct BuildSettingResolverTests {
    @Test
    func resolveForKey() throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")
        let projectFilePath = projectFolder.appendingPathComponent("Hello.xcodeproj").path
        let derivedDataPath = PathHash.derivedDataFullPath(for: projectFilePath)
        let xcodeGlobalSettings = XcodeGlobalSettings(derivedDataPath: derivedDataPath)

        // Arrange
        let xcodeProj = try XcodeProj(path: Path(projectFilePath))
        let resolver = BuildSettingResolver(
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: "Hello",
            configuration: "Debug"
        )

        // Act
        let result = resolver.resolve(forKey: "SDKROOT")
        let deploymentTarget = resolver.resolve(forKey: "IPHONEOS_DEPLOYMENT_TARGET")
    }
}

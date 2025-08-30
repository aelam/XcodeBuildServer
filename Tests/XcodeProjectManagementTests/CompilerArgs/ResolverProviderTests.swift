import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct CompilerArgumentsProviderTests {
    //
    @Test
    func resolveCompilerFlags() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")
        let projectFilePath = projectFolder
            .appendingPathComponent("Hello.xcodeproj").path
        let derivedDataPath = PathHash.derivedDataFullPath(for: projectFilePath)
        let xcodeGlobalSettings =
            XcodeGlobalSettings(derivedDataPath: derivedDataPath)

        let xcodeToolchain = XcodeToolchain()
        try await xcodeToolchain.initialize()
        guard let xcodeInstallation = await xcodeToolchain
            .getSelectedInstallation() else {
            return
        }

        let xcodeProj = try XcodeProj(path: Path(projectFilePath))
        let resolver = try BuildSettingResolver(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: "Hello",
            configuration: "Debug"
        )

        let helloAppSwift = projectFolder
            .appendingPathComponent("Hello")
            .appendingPathComponent("HelloApp.swift")

        let flags = ResolverProvider(
            resolver: resolver,
            compilerType: .swift
        ).arguments(
            for: helloAppSwift,
            compilerType: .swift
        )
        print(flags)
    }
}

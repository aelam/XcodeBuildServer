import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct CompilerArgsGeneratorTests {
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
        guard let xcodeInstallation = await xcodeToolchain
            .getSelectedInstallation() else {
            return
        }
        try await xcodeToolchain.initialize()
        let xcodeProj = try XcodeProj(path: Path(projectFilePath))

        let helloAppSwift = projectFolder
            .appendingPathComponent("Hello")
            .appendingPathComponent("HelloApp.swift")

        let generator = try CompileArgGenerator.create(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: "Hello",
            configurationName: "Debug",
            fileURL: helloAppSwift
        )

        let flags = generator.compileArguments(
            for: helloAppSwift,
            compilerType: .swift
        )
        print(flags)
    }
}

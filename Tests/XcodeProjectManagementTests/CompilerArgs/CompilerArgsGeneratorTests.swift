import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct CompilerArgsGeneratorTests {
    //
    @Test
    func resolveProjectSwiftCompilerFlags() async throws {
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
        try await xcodeToolchain.initialize()
        let xcodeProj = try XcodeProj(path: Path(projectFilePath))

        let swiftFile = projectFolder
            .appendingPathComponent("HelloObjectiveC")
            .appendingPathComponent("SceneDelegate.swift")

        let generator = try CompileArgGenerator.create(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: "HelloObjectiveC",
            configurationName: "Debug",
            fileURL: swiftFile
        )
        print("=============================")
        let flags = generator.compileArguments()
        for flag in flags {
            print(flag)
        }
        print("=============================")
    }

    @Test
    func resolveProjectClangCompilerFlags() async throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloWorkspace")
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
        try await xcodeToolchain.initialize()
        let xcodeProj = try XcodeProj(path: Path(projectFilePath))

        let clangFile = projectFolder
            .appendingPathComponent("HelloObjectiveC")
            .appendingPathComponent("Person.m")

        let generator = try CompileArgGenerator.create(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: "HelloObjectiveC",
            configurationName: "Debug",
            fileURL: clangFile
        )
        print("=============================")
        let flags = generator.compileArguments()
        for flag in flags {
            print(flag)
        }
        print("=============================")
    }
}

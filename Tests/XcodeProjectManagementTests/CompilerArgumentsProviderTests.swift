import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct CompilerArgumentsProviderTests {
    //
    @Test
    func resolveCompilerFlags() throws {
        let projectFolder = Bundle.module.resourceURL!
            .appendingPathComponent("DemoProjects")
            .appendingPathComponent("HelloProject")
        let projectFilePath = projectFolder.appendingPathComponent("Hello.xcodeproj").path
        let derivedDataPath = PathHash.derivedDataFullPath(for: projectFilePath)
        let xcodeGlobalSettings = XcodeGlobalSettings(derivedDataPath: derivedDataPath)

        let xcodeProj = try XcodeProj(path: Path(projectFilePath))
        let resolver = BuildSettingResolver(
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: "Hello",
            configuration: "Debug"
        )

        let helloAppSwift = projectFolder
            .appendingPathComponent("Hello")
            .appendingPathComponent("HelloApp.swift")

        let flags = CompilerArgumentsProvider(
            resolver: resolver,
            compilerType: .swift
        ).compileArguments(for: helloAppSwift)
        print(flags)
    }
}

import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct FlashSpaceTests {
    @Test
    func resolveMacProject() async throws {
        let projectRoot = "/Users/wang.lun/Work/FlashSpace"
        let projectFile = "FlashSpace.xcodeproj"
        let targetName = "FlashSpace"
        let fileSubPath = "FlashSpace/App/AppDelegate.swift"

        let projectFolder = URL(fileURLWithPath: projectRoot)
        let projectFilePath = projectFolder
            .appendingPathComponent(projectFile).path
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

        let file = projectFolder
            .appendingPathComponent(fileSubPath)

        let targetIdentifier = TargetIdentifier(
            projectFilePath: projectFilePath,
            targetName: targetName
        )
        let sourceItems = SourceFileLister.loadSourceFiles(
            for: xcodeProj,
            targets: [targetName]
        )[targetIdentifier.rawValue] ?? []

        let generator = try CompileArgGenerator.create(
            xcodeInstallation: xcodeInstallation,
            xcodeGlobalSettings: xcodeGlobalSettings,
            xcodeProj: xcodeProj,
            target: targetName,
            configurationName: "Debug",
            fileURL: file,
            sourceItems: sourceItems
        )
        print("=============================")
        let flags = generator.compileArguments()
        for flag in flags {
            print(flag)
        }
        print("=============================")
    }
}

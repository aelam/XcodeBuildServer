import Foundation
import PathKit
import Testing
import XcodeProj
@testable import XcodeProjectManagement

struct UserStickersCompilerArgsGeneratorTests {
    @Test
    func resolveUserStickersProject() async throws {
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }

        let targetName = "UserStickersNotificationService"
        let fileSubPath = "UserStickersNotificationService/NotificationService.swift"
        let projectFolder = URL(fileURLWithPath: "/Users/wang.lun/Work/line-stickers-ios")
        let projectFilePath = projectFolder
            .appendingPathComponent("UserStickers/UserStickers.xcodeproj").path
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

        let targetIdentifier = XcodeTargetIdentifier(
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

    @Test
    func resolveUserStickersStudioFoundation() async throws {
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }

        let targetName = "StudioFoundation-Unit-Tests"
        let fileSubPath = "UserStickers/StudioFoundation/Sources/StudioFoundation/Apple/CoreGraphics/CGAffineTransform+Extension.swift"
        let projectFolder = URL(fileURLWithPath: "/Users/wang.lun/Work/line-stickers-ios")
        let projectFilePath = projectFolder
            .appendingPathComponent("Pods/Pods.xcodeproj").path
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

        let targetIdentifier = XcodeTargetIdentifier(
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

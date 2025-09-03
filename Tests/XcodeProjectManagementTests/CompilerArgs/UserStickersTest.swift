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

        let fileInfo = SourceFileInfo(
            projectFolder: URL(fileURLWithPath: "/Users/wang.lun/Work/line-stickers-ios"),
            filePath: "UserStickersNotificationService/NotificationService.swift",
            projectFilePath: "UserStickers/UserStickers.xcodeproj",
            targetName: "UserStickersNotificationService"
        )

        try await processFileCompileArguments(fileInfo)
    }

    @Test
    func resolveUserStickersStudioFoundation() async throws {
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }

        let fileInfo = SourceFileInfo(
            projectFolder: URL(fileURLWithPath: "/Users/wang.lun/Work/line-stickers-ios"),
            // swiftlint:disable:next line_length
            filePath: "UserStickers/StudioFoundation/Sources/StudioFoundation/Apple/CoreGraphics/CGAffineTransform+Extension.swift",
            projectFilePath: "Pods/Pods.xcodeproj",
            targetName: "StudioFoundation-Unit-Tests"
        )
        try await processFileCompileArguments(fileInfo)
    }

    @Test
    func resolveUserStickers() async throws {
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }

        let fileInfo = SourceFileInfo(
            projectFolder: URL(fileURLWithPath: "/Users/wang.lun/Work/line-stickers-ios"),
            filePath: "UserStickers/Editor/Tests/BrushCoreTests/AngleUtilTests.swift",
            projectFilePath: "Pods/Pods.xcodeproj",
            targetName: "Editor-Unit-Tests"
        )
        try await processFileCompileArguments(fileInfo)
    }
}

//
//  TargetDependencyTests.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/09/07.
//

import PathKit
import Testing
import XcodeProj
import XcodeProjectManagement

struct TargetDependencyTests {
    @Test("Target Dependency Test")
    func targetDependency() throws {
        let xcodeProjPath = "/Users/wang.lun/Work/line-stickers-ios/UserStickers/UserStickers.xcodeproj"
        let podProjPath = "/Users/wang.lun/Work/line-stickers-ios/Pods/Pods.xcodeproj"

        let primayXcodeProj = try XcodeProj(path: Path(xcodeProjPath))
        let podXcodeProj = try XcodeProj(path: Path(podProjPath))

        let resolver = XcodeBuildGraph(
            primaryXcodeProj: primayXcodeProj,
            additionalXcodeProjs: [podXcodeProj]
        )

        let targetIdentifier = XcodeTargetIdentifier(
            projectFilePath: xcodeProjPath,
            targetName: "UserStickers"
        )

        print(resolver.buildOrder(for: targetIdentifier))
    }
}

//
//  XcodeBuildCommandBuilderTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct TestCase {
    let name: String
    let config: XcodeProjectConfiguration
    let expectedArgs: [String]
    let additionalExpectedArgs: [String]

    init(
        name: String,
        config: XcodeProjectConfiguration,
        expectedArgs: [String],
        additionalExpectedArgs: [String] = []
    ) {
        self.name = name
        self.config = config
        self.expectedArgs = expectedArgs
        self.additionalExpectedArgs = additionalExpectedArgs
    }
}

struct XcodeBuildCommandBuilderTests {
    static let testConfigurations = [
        TestCase(
            name: "workspace",
            config: .workspace(
                workspaceURL: URL(fileURLWithPath: "/test/Test.xcworkspace"),
                scheme: "TestScheme"
            ),
            expectedArgs: [
                "-workspace", "/test/Test.xcworkspace",
                "-scheme", "TestScheme",
            ]
        ),
        TestCase(
            name: "projectWithScheme",
            config: .project(
                projectURL: URL(fileURLWithPath: "/test/Test.xcodeproj"),
                buildMode: .scheme("TestScheme")
            ),
            expectedArgs: [
                "-project", "/test/Test.xcodeproj",
                "-scheme", "TestScheme",
            ]
        ),
        TestCase(
            name: "projectWithTargets",
            config: .project(
                projectURL: URL(fileURLWithPath: "/test/Test.xcodeproj"),
                buildMode: .targets(["TestTarget1", "TestTarget2"])
            ),
            expectedArgs: [
                "-project", "/test/Test.xcodeproj",
                "-target", "TestTarget1",
                "-target", "TestTarget2",
            ],
            additionalExpectedArgs: ["TestTarget1", "TestTarget2"]
        )
    ]

    static let derivedDataPaths = [
        nil,
        "/custom/derived/data/path"
    ]

    static let derivedDataPathTestCases = [
        (path: nil as String?, expectedArgs: [] as [String]),
        (path: "/custom/derived/data/path", expectedArgs: ["-derivedDataPath", "/custom/derived/data/path"])
    ]

    @Test(arguments: testConfigurations)
    func buildBasicCommand(testCase: TestCase) {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: testCase.config,
            options: XcodeBuildOptions()
        )

        for expectedArg in testCase.expectedArgs {
            #expect(
                command.contains(expectedArg),
                "Missing expected argument: \(expectedArg) in command: \(command)"
            )
        }
    }

    @Test(arguments: derivedDataPathTestCases)
    func buildSettingsCommand(testCase: (path: String?, expectedArgs: [String])) {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: .project(
                projectURL: URL(fileURLWithPath: "/test/Test.xcodeproj"),
                buildMode: .targets(["TestTarget"])
            ),
            options: XcodeBuildOptions.buildSettingsJSON(derivedDataPath: testCase.path)
        )

        let expectedArgs = ["-showBuildSettings", "-json", "TestTarget"] +
            testCase.expectedArgs
        for expectedArg in expectedArgs {
            #expect(command.contains(expectedArg))
        }
    }

    @Test(arguments: derivedDataPathTestCases)
    func buildSettingsForIndexCommand(testCase: (path: String?, expectedArgs: [String])) {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: .workspace(
                workspaceURL: URL(fileURLWithPath: "/test/Test.xcworkspace"),
                scheme: "TestScheme"
            ),
            options: XcodeBuildOptions.buildSettingsForIndexJSON(derivedDataPath: testCase.path)
        )

        let expectedArgs = ["-showBuildSettingsForIndex", "-json"] +
            testCase.expectedArgs
        for expectedArg in expectedArgs {
            #expect(command.contains(expectedArg))
        }
    }

    @Test(arguments: testConfigurations)
    func listSchemesCommand(testCase: TestCase) {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.listSchemesCommand(project: testCase.config)

        #expect(command.contains("-list"))
        #expect(command.contains("-json"))

        // Check for project or workspace specific args
        let projectArgs = Array(testCase.expectedArgs.prefix(2))
        for arg in projectArgs {
            #expect(
                command.contains(arg),
                "Missing expected argument: \(arg) in command: \(command)"
            )
        }
    }

    @Test(arguments: zip(
        testConfigurations,
        derivedDataPathTestCases.flatMap { derivedCase in
            Array(repeating: derivedCase, count: testConfigurations.count)
        }
    ))
    func quietBuildCommand(testCase: TestCase, derivedCase: (path: String?, expectedArgs: [String])) {
        let builder = XcodeBuildCommandBuilder()
        let options = XcodeBuildOptions(
            command: .list,
            flags: XcodeBuildFlags.quiet
        )
        let command = builder.buildCommand(
            project: testCase.config,
            options: options
        )

        let expectedArgs = ["-quiet"] + derivedCase.expectedArgs + testCase.additionalExpectedArgs
        for expectedArg in expectedArgs {
            #expect(command.contains(expectedArg))
        }
    }
}

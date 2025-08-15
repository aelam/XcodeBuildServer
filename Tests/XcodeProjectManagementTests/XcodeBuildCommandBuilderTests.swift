//
//  XcodeBuildCommandBuilderTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeBuildCommandBuilderTests {
    @Test
    func buildBasicCommand() {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: XcodeProjectConfiguration(
                workspaceURL: URL(fileURLWithPath: "/test/Test.xcworkspace"),
                scheme: "TestScheme",
                configuration: "Debug"
            ),
            options: XcodeBuildOptions()
        )

        #expect(command.contains("-workspace"))
        #expect(command.contains("/test/Test.xcworkspace"))
        #expect(command.contains("-scheme"))
        #expect(command.contains("TestScheme"))
        #expect(command.contains("-configuration"))
        #expect(command.contains("Debug"))
    }

    @Test
    func buildSettingsCommand() {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: XcodeProjectConfiguration(
                projectURL: URL(fileURLWithPath: "/test/Test.xcodeproj"),
                targets: ["TestTarget"],
                configuration: "Debug"
            ),
            options: XcodeBuildOptions.buildSettingsJSON()
        )

        #expect(command.contains("-showBuildSettings"))
        #expect(command.contains("-json"))
        #expect(command.contains("TestTarget"))
    }

    @Test
    func buildSettingsForIndexCommand() {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: XcodeProjectConfiguration(
                workspaceURL: URL(fileURLWithPath: "/test/Test.xcworkspace"),
                configuration: "Debug"
            ),
            options: XcodeBuildOptions.buildSettingsForIndexJSON()
        )

        #expect(command.contains("-showBuildSettingsForIndex"))
        #expect(command.contains("-json"))
    }

    @Test
    func listSchemesCommand() {
        let builder = XcodeBuildCommandBuilder()
        let command = builder.buildCommand(
            project: XcodeProjectConfiguration(
                workspaceURL: URL(fileURLWithPath: "/test/Test.xcworkspace"),
                configuration: "Debug"
            ),
            options: XcodeBuildOptions.listSchemesJSON
        )

        #expect(command.contains("-list"))
        #expect(command.contains("-json"))
        #expect(command.contains("-workspace"))
    }

    @Test
    func quietBuildCommand() {
        let builder = XcodeBuildCommandBuilder()
        let options = XcodeBuildOptions(quiet: true)
        let command = builder.buildCommand(
            project: XcodeProjectConfiguration(
                projectURL: URL(fileURLWithPath: "/test/Test.xcodeproj"),
                targets: ["TestTarget"],
                configuration: "Debug"
            ),
            options: options
        )

        #expect(command.contains("-quiet"))
        #expect(command.contains("TestTarget"))
    }
}

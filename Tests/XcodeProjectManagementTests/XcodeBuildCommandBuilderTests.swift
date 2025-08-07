//
//  XcodeBuildCommandBuilderTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeBuildCommandBuilderTests {
    let projectIdentifier = XcodeProjectIdentifier(
        rootURL: URL(fileURLWithPath: "/test"),
        projectLocation: .explicitWorkspace(URL(fileURLWithPath: "/test/Test.xcworkspace"))
    )

    @Test
    func buildBasicCommand() {
        let builder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let command = builder.buildCommand(
            scheme: "TestScheme",
            configuration: "Debug"
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
        let builder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let command = builder.buildCommand(
            scheme: "TestScheme",
            configuration: "Debug",
            options: XcodeBuildOptions.buildSettingsJSON
        )

        #expect(command.contains("-showBuildSettings"))
        #expect(command.contains("-json"))
        #expect(command.contains("TestScheme"))
    }

    @Test
    func buildSettingsForIndexCommand() {
        let builder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let command = builder.buildCommand(
            scheme: "TestScheme",
            configuration: "Debug",
            options: XcodeBuildOptions.buildSettingsForIndexJSON
        )

        #expect(command.contains("-showBuildSettingsForIndex"))
        #expect(command.contains("-json"))
    }

    @Test
    func listSchemesCommand() {
        let builder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let command = builder.buildCommand(options: XcodeBuildOptions.listSchemesJSON)

        #expect(command.contains("-list"))
        #expect(command.contains("-json"))
        #expect(command.contains("-workspace"))
    }

    @Test
    func quietBuildCommand() {
        let builder = XcodeBuildCommandBuilder(projectIdentifier: projectIdentifier)
        let options = XcodeBuildOptions(quiet: true)
        let command = builder.buildCommand(
            scheme: "TestScheme",
            configuration: "Debug",
            options: options
        )

        #expect(command.contains("-quiet"))
        #expect(command.contains("TestScheme"))
    }
}

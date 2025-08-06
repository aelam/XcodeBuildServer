//
//  XcodeBuildCommandBuilderTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeBuildCommandBuilderTests {
    let projectInfo = XcodeProjectInfo(
        rootURL: URL(fileURLWithPath: "/test"),
        projectType: .explicitWorkspace(URL(fileURLWithPath: "/test/Test.xcworkspace")),
        scheme: "TestScheme",
        configuration: "Debug"
    )

    @Test
    func buildBasicCommand() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildCommand()

        #expect(command.contains("-workspace"))
        #expect(command.contains("/test/Test.xcworkspace"))
        #expect(command.contains("-scheme"))
        #expect(command.contains("TestScheme"))
        #expect(command.contains("-configuration"))
        #expect(command.contains("Debug"))
    }

    @Test
    func buildCommandWithAction() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildCommand(action: .build)

        #expect(command.contains("build"))
    }

    @Test
    func buildCommandWithDestination() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildCommand(destination: .iOSSimulator)

        #expect(command.contains("-destination"))
        #expect(command.contains("generic/platform=iOS Simulator"))
    }

    @Test
    func buildSettingsCommand() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildSettingsCommand()

        #expect(command.contains("-showBuildSettings"))
        #expect(command.contains("-json"))
    }

    @Test
    func buildSettingsForIndexCommand() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildSettingsCommand(forIndex: true)

        #expect(command.contains("-showBuildSettingsForIndex"))
        #expect(command.contains("-json"))
    }

    @Test
    func listSchemesCommand() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.listSchemesCommand()

        #expect(command.contains("-list"))
    }

    @Test
    func buildForBSPCommand() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildForBSP()

        #expect(command.contains("build"))
        #expect(command.contains("-destination"))
        #expect(command.contains("-verbose"))
    }

    @Test
    func listSchemesJSONOption() {
        let builder = XcodeBuildCommandBuilder(projectInfo: projectInfo)
        let command = builder.buildCommand(options: .listSchemesJSON)

        #expect(command.contains("-workspace"))
        #expect(command.contains("/test/Test.xcworkspace"))
        #expect(command.contains("-list"))
        #expect(command.contains("-json"))
    }
}

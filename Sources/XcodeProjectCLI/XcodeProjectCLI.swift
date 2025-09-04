//
//  XcodeProjectCLI.swift
//
//  Copyright © 2024 Wang Lun.
//
//  Example usage of the XcodeProjectManagement module

import ArgumentParser
import Foundation
import Logger
import PathKit
import XcodeProj
import XcodeProjectManagement

@main
struct XcodeProjectCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "XcodeProjectCLI",
        subcommands: [
            ResolveProjectCommand.self,
            BuildSettingsCommand.self,
            CompileArgumentsCommand.self
        ]
    )
}

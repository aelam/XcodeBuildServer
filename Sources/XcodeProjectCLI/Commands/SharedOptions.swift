//
//  SharedOptions.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/09/04.
//

import ArgumentParser

struct SharedOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Xcode project/workspace folder path")
    var workspaceFolder: String

    @Option(
        name: .shortAndLong,
        help: "Xcode project file path relative to the workspace folder, e.g., MyApp.xcodeproj"
    )
    var projectFilePath: String

    @Option(name: .shortAndLong, help: "Xcode target name")
    var targetName: String

    @Option(name: .shortAndLong, help: "Build configuration, e.g., Debug or Release")
    var configuration: String = "Debug"
}

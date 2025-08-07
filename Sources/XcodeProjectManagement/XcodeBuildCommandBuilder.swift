//
//  XcodeBuildCommandBuilder.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public enum XcodeBuildAction: String, CaseIterable, Sendable {
    case build
    case clean
    case test
    case archive
    case analyze
    case installsrc
    case install
}

public enum XcodeBuildDestination: Sendable {
    case macOS
    case iOS
    case iOSSimulator
    case watchOS
    case watchOSSimulator
    case tvOS
    case tvOSSimulator
    case custom(String)

    public var destinationString: String {
        switch self {
        case .macOS:
            "generic/platform=macOS"
        case .iOS:
            "generic/platform=iOS"
        case .iOSSimulator:
            "generic/platform=iOS Simulator"
        case .watchOS:
            "generic/platform=watchOS"
        case .watchOSSimulator:
            "generic/platform=watchOS Simulator"
        case .tvOS:
            "generic/platform=tvOS"
        case .tvOSSimulator:
            "generic/platform=tvOS Simulator"
        case let .custom(destination):
            destination
        }
    }
}

public struct XcodeBuildOptions: Sendable {
    public let showBuildSettings: Bool
    public let showBuildSettingsForIndex: Bool
    public let json: Bool
    public let quiet: Bool
    public let verbose: Bool
    public let dryRun: Bool
    public let list: Bool
    public let showdestinations: Bool
    public let derivedDataPath: String?
    public let resultBundlePath: String?
    public let customFlags: [String]

    public init(
        showBuildSettings: Bool = false,
        showBuildSettingsForIndex: Bool = false,
        json: Bool = false,
        quiet: Bool = false,
        verbose: Bool = false,
        dryRun: Bool = false,
        list: Bool = false,
        showdestinations: Bool = false,
        derivedDataPath: String? = nil,
        resultBundlePath: String? = nil,
        customFlags: [String] = []
    ) {
        self.showBuildSettings = showBuildSettings
        self.showBuildSettingsForIndex = showBuildSettingsForIndex
        self.json = json
        self.quiet = quiet
        self.verbose = verbose
        self.dryRun = dryRun
        self.list = list
        self.showdestinations = showdestinations
        self.derivedDataPath = derivedDataPath
        self.resultBundlePath = resultBundlePath
        self.customFlags = customFlags
    }

    public static let buildSettingsJSON = XcodeBuildOptions(
        showBuildSettings: true,
        json: true
    )

    public static let buildSettingsForIndexJSON = XcodeBuildOptions(
        showBuildSettingsForIndex: true,
        json: true
    )

    public static let listSchemes = XcodeBuildOptions(list: true)

    public static let listSchemesJSON = XcodeBuildOptions(json: true, list: true)
}

public struct XcodeBuildCommandBuilder {
    private let projectIdentifer: XcodeProjectIdentifier

    public init(projectIdentifer: XcodeProjectIdentifier) {
        self.projectIdentifer = projectIdentifer
    }

    public func buildCommand(
        action: XcodeBuildAction? = nil,
        scheme: String? = nil,
        configuration: String? = nil,
        destination: XcodeBuildDestination? = nil,
        options: XcodeBuildOptions = XcodeBuildOptions()
    ) -> [String] {
        var arguments: [String] = []

        arguments.append(contentsOf: buildWorkspaceOrProjectArguments())

        if let scheme {
            arguments.append(contentsOf: ["-scheme", scheme])
        }

        if let configuration {
            arguments.append(contentsOf: ["-configuration", configuration])
        }
        if let destination {
            arguments.append(contentsOf: ["-destination", destination.destinationString])
        }

        if let action {
            arguments.append(action.rawValue)
        }

        arguments.append(contentsOf: buildOptionsArguments(options: options))

        return arguments
    }

    public func buildSettingsCommand(
        destination: XcodeBuildDestination? = nil,
        forIndex: Bool = false
    ) -> [String] {
        let options = forIndex ? XcodeBuildOptions.buildSettingsForIndexJSON : XcodeBuildOptions.buildSettingsJSON
        return buildCommand(destination: destination, options: options)
    }

    public func listSchemesCommand() -> [String] {
        buildCommand(options: XcodeBuildOptions.listSchemes)
    }

    public func buildForBSP(
        action: XcodeBuildAction = .build,
        destination: XcodeBuildDestination = .iOSSimulator
    ) -> [String] {
        let options = XcodeBuildOptions(
            quiet: false,
            verbose: true,
            derivedDataPath: "TODOC"
        )
        return buildCommand(action: action, destination: destination, options: options)
    }

    private func buildWorkspaceOrProjectArguments() -> [String] {
        switch projectIdentifer.projectType {
        case let .explicitWorkspace(url):
            ["-workspace", url.path]
        case let .implicitProjectWorkspace(url):
            ["-workspace", url.path]
        }
    }

    private func buildOptionsArguments(options: XcodeBuildOptions) -> [String] {
        var arguments: [String] = []

        if options.showBuildSettings {
            arguments.append("-showBuildSettings")
        }

        if options.showBuildSettingsForIndex {
            arguments.append("-showBuildSettingsForIndex")
        }

        if options.json {
            arguments.append("-json")
        }

        if options.quiet {
            arguments.append("-quiet")
        }

        if options.verbose {
            arguments.append("-verbose")
        }

        if options.dryRun {
            arguments.append("-dry-run")
        }

        if options.list {
            arguments.append("-list")
        }

        if options.showdestinations {
            arguments.append("-showdestinations")
        }

        if let derivedDataPath = options.derivedDataPath {
            arguments.append(contentsOf: ["-derivedDataPath", derivedDataPath])
        }

        if let resultBundlePath = options.resultBundlePath {
            arguments.append(contentsOf: ["-resultBundlePath", resultBundlePath])
        }

        arguments.append(contentsOf: options.customFlags)

        return arguments
    }
}

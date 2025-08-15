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

public enum XcodeProjectConfiguration: Sendable {
    public enum ProjectBuildMode: Sendable {
        case scheme(String)
        case targets([String])
    }

    case project(projectURL: URL, buildMode: ProjectBuildMode, configuration: String?)
    case workspace(workspaceURL: URL, scheme: String?, configuration: String?)

    public init(projectURL: URL, targets: [String] = [], configuration: String? = nil) {
        self = .project(projectURL: projectURL, buildMode: .targets(targets), configuration: configuration)
    }

    public init(workspaceURL: URL, scheme: String? = nil, configuration: String? = nil) {
        self = .workspace(workspaceURL: workspaceURL, scheme: scheme, configuration: configuration)
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

    public static let listSchemesJSON = XcodeBuildOptions(json: true, list: true)
}

public struct XcodeBuildCommandBuilder {
    /// New buildCommand method using XcodeProjectConfiguration
    public func buildCommand(
        project: XcodeProjectConfiguration,
        action: XcodeBuildAction? = nil,
        destination: XcodeBuildDestination? = nil,
        options: XcodeBuildOptions = XcodeBuildOptions()
    ) -> [String] {
        var arguments: [String] = []

        switch project {
        case let .project(projectURL, buildMode, configuration):
            arguments.append(contentsOf: ["-project", projectURL.path])
            switch buildMode {
            case let .targets(targets):
                for target in targets {
                    arguments.append(contentsOf: ["-target", target])
                }
            case let .scheme(scheme):
                arguments.append(contentsOf: ["-scheme", scheme])
            }
            if let configuration {
                arguments.append(contentsOf: ["-configuration", configuration])
            }
        case let .workspace(workspaceURL, scheme, configuration):
            arguments.append(contentsOf: ["-workspace", workspaceURL.path])
            if let scheme {
                arguments.append(contentsOf: ["-scheme", scheme])
            }
            if let configuration {
                arguments.append(contentsOf: ["-configuration", configuration])
            }
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

    // /// Legacy buildCommand method for backward compatibility
    // public func buildCommand(
    //     workspaceURL: URL? = nil,
    //     projectURL: URL? = nil,
    //     action: XcodeBuildAction? = nil,
    //     scheme: String? = nil, // required for workspace project
    //     targets: [String] = [], // only work with non-workspace
    //     configuration: String? = nil,
    //     destination: XcodeBuildDestination? = nil,
    //     options: XcodeBuildOptions = XcodeBuildOptions(),
    //     derivedDataPath: URL? = nil
    // ) -> [String] {
    //     // Convert legacy parameters to new XcodeProjectConfiguration format
    //     let projectConfig: XcodeProjectConfiguration

    //     if let projectURL {
    //         projectConfig = XcodeProjectConfiguration(
    //             projectURL: projectURL,
    //             targets: targets,
    //             configuration: configuration
    //         )
    //     } else if let workspaceURL, let scheme {
    //         projectConfig = XcodeProjectConfiguration(
    //             workspaceURL: workspaceURL,
    //             scheme: scheme,
    //             configuration: configuration
    //         )
    //     } else {
    //         // Fallback to original logic for auto-detection
    //         var arguments: [String] = []
    //         arguments.append(contentsOf: buildWorkspaceOrProjectArguments())

    //         if let scheme {
    //             arguments.append(contentsOf: ["-scheme", scheme])
    //         }
    //         if !targets.isEmpty {
    //             // -target <target> -target <target>
    //             for target in targets {
    //                 arguments.append(contentsOf: ["-target", target])
    //             }
    //         }
    //         if let configuration {
    //             arguments.append(contentsOf: ["-configuration", configuration])
    //         }
    //         if let destination {
    //             arguments.append(contentsOf: ["-destination", destination.destinationString])
    //         }
    //         if let action {
    //             arguments.append(action.rawValue)
    //         }

    //         arguments.append(contentsOf: buildOptionsArguments(options: options))

    //         if let derivedDataPath {
    //             arguments.append(contentsOf: ["-derivedDataPath", derivedDataPath.path])
    //         }

    //         return arguments
    //     }

    //     // Use the new method
    //     return buildCommand(
    //         project: projectConfig,
    //         action: action,
    //         destination: destination,
    //         derivedDataPath: derivedDataPath,
    //         options: options
    //     )
    // }

    // public func buildSettingsCommand(
    //     workspaceURL: URL?,
    //     projectURL: URL?,
    //     scheme: String?,
    //     targets: [String] = [],
    //     destination: XcodeBuildDestination? = nil,
    //     forIndex: Bool = false,
    //     derivedDataPath: URL? = nil
    // ) -> [String] {
    //     let options = forIndex ? XcodeBuildOptions.buildSettingsForIndexJSON : XcodeBuildOptions.buildSettingsJSON
    //     return buildCommand(
    //         workspaceURL: workspaceURL,
    //         projectURL: projectURL,
    //         scheme: scheme,
    //         targets: targets,
    //         destination: destination,
    //         options: options
    //     )
    // }

    public func listSchemesCommand(project: XcodeProjectConfiguration) -> [String] {
        buildCommand(
            project: project,
            options: XcodeBuildOptions.listSchemesJSON
        )
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

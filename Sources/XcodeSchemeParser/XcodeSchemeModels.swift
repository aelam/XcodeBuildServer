//
//  XcodeSchemeModels.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

// MARK: - Core XML Element Models

public struct XcodeSchemeBuildableReference: Sendable, Equatable, Hashable {
    public let buildableIdentifier: String // e.g., "primary"
    public let blueprintIdentifier: String
    public let buildableName: String?
    public let blueprintName: String // target name
    public let referencedContainer: String?

    public init(
        buildableIdentifier: String,
        blueprintIdentifier: String,
        buildableName: String? = nil,
        blueprintName: String,
        referencedContainer: String? = nil
    ) {
        self.buildableIdentifier = buildableIdentifier
        self.blueprintIdentifier = blueprintIdentifier
        self.buildableName = buildableName
        self.blueprintName = blueprintName
        self.referencedContainer = referencedContainer
    }
}

/// Represents BuildActionEntry with build flags
public struct XcodeSchemeBuildActionEntry: Sendable, Equatable, Hashable {
    public let buildForTesting: Bool
    public let buildForRunning: Bool
    public let buildForProfiling: Bool
    public let buildForArchiving: Bool
    public let buildForAnalyzing: Bool
    public let buildableReference: XcodeSchemeBuildableReference

    public init(
        buildForTesting: Bool,
        buildForRunning: Bool,
        buildForProfiling: Bool,
        buildForArchiving: Bool,
        buildForAnalyzing: Bool,
        buildableReference: XcodeSchemeBuildableReference
    ) {
        self.buildForTesting = buildForTesting
        self.buildForRunning = buildForRunning
        self.buildForProfiling = buildForProfiling
        self.buildForArchiving = buildForArchiving
        self.buildForAnalyzing = buildForAnalyzing
        self.buildableReference = buildableReference
    }

    // Convenience initializer for backward compatibility
    public init(
        targetName: String,
        blueprintIdentifier: String,
        buildForTesting: Bool,
        buildForRunning: Bool,
        buildForProfiling: Bool,
        buildForArchiving: Bool,
        buildForAnalyzing: Bool,
        buildableIdentifier: String? = nil,
        buildableName: String? = nil,
        referencedContainer: String? = nil
    ) {
        self.buildForTesting = buildForTesting
        self.buildForRunning = buildForRunning
        self.buildForProfiling = buildForProfiling
        self.buildForArchiving = buildForArchiving
        self.buildForAnalyzing = buildForAnalyzing
        self.buildableReference = XcodeSchemeBuildableReference(
            buildableIdentifier: buildableIdentifier ?? "primary",
            blueprintIdentifier: blueprintIdentifier,
            buildableName: buildableName,
            blueprintName: targetName,
            referencedContainer: referencedContainer
        )
    }
}

// MARK: - Type Aliases

public typealias XcodeSchemeTargetInfo = XcodeSchemeBuildActionEntry

// MARK: - Action Models

public struct XcodeSchemeBuildAction: Sendable {
    public let parallelizeBuildables: Bool
    public let buildImplicitDependencies: Bool
    public let buildActionEntries: [XcodeSchemeBuildActionEntry]

    public init(
        parallelizeBuildables: Bool = false,
        buildImplicitDependencies: Bool = false,
        buildActionEntries: [XcodeSchemeBuildActionEntry] = []
    ) {
        self.parallelizeBuildables = parallelizeBuildables
        self.buildImplicitDependencies = buildImplicitDependencies
        self.buildActionEntries = buildActionEntries
    }
}

public struct XcodeSchemeTestableReference: Sendable {
    public let skipped: Bool
    public let buildableReference: XcodeSchemeBuildableReference

    public init(skipped: Bool = false, buildableReference: XcodeSchemeBuildableReference) {
        self.skipped = skipped
        self.buildableReference = buildableReference
    }
}

public struct XcodeSchemeTestAction: Sendable {
    public let buildConfiguration: String?
    public let selectedDebuggerIdentifier: String?
    public let selectedLauncherIdentifier: String?
    public let shouldUseLaunchSchemeArgsEnv: Bool
    public let testables: [XcodeSchemeTestableReference]

    public init(
        buildConfiguration: String? = nil,
        selectedDebuggerIdentifier: String? = nil,
        selectedLauncherIdentifier: String? = nil,
        shouldUseLaunchSchemeArgsEnv: Bool = true,
        testables: [XcodeSchemeTestableReference] = []
    ) {
        self.buildConfiguration = buildConfiguration
        self.selectedDebuggerIdentifier = selectedDebuggerIdentifier
        self.selectedLauncherIdentifier = selectedLauncherIdentifier
        self.shouldUseLaunchSchemeArgsEnv = shouldUseLaunchSchemeArgsEnv
        self.testables = testables
    }
}

public struct XcodeSchemeCommandLineArgument: Sendable {
    public let argument: String
    public let isEnabled: Bool

    public init(argument: String, isEnabled: Bool = true) {
        self.argument = argument
        self.isEnabled = isEnabled
    }
}

public struct XcodeSchemeEnvironmentVariable: Sendable {
    public let key: String
    public let value: String
    public let isEnabled: Bool

    public init(key: String, value: String, isEnabled: Bool = true) {
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

public struct XcodeSchemeBuildableProductRunnable: Sendable {
    public let runnableDebuggingMode: String?
    public let buildableReference: XcodeSchemeBuildableReference

    public init(runnableDebuggingMode: String? = nil, buildableReference: XcodeSchemeBuildableReference) {
        self.runnableDebuggingMode = runnableDebuggingMode
        self.buildableReference = buildableReference
    }
}

public struct XcodeSchemeLaunchAction: Sendable {
    public let buildConfiguration: String?
    public let selectedDebuggerIdentifier: String?
    public let selectedLauncherIdentifier: String?
    public let launchStyle: String?
    public let useCustomWorkingDirectory: Bool
    public let ignoresPersistentStateOnLaunch: Bool
    public let debugDocumentVersioning: Bool
    public let debugServiceExtension: String?
    public let allowLocationSimulation: Bool
    public let buildableProductRunnable: XcodeSchemeBuildableProductRunnable?
    public let commandLineArguments: [XcodeSchemeCommandLineArgument]
    public let environmentVariables: [XcodeSchemeEnvironmentVariable]

    public init(
        buildConfiguration: String? = nil,
        selectedDebuggerIdentifier: String? = nil,
        selectedLauncherIdentifier: String? = nil,
        launchStyle: String? = nil,
        useCustomWorkingDirectory: Bool = false,
        ignoresPersistentStateOnLaunch: Bool = false,
        debugDocumentVersioning: Bool = false,
        debugServiceExtension: String? = nil,
        allowLocationSimulation: Bool = false,
        buildableProductRunnable: XcodeSchemeBuildableProductRunnable? = nil,
        commandLineArguments: [XcodeSchemeCommandLineArgument] = [],
        environmentVariables: [XcodeSchemeEnvironmentVariable] = []
    ) {
        self.buildConfiguration = buildConfiguration
        self.selectedDebuggerIdentifier = selectedDebuggerIdentifier
        self.selectedLauncherIdentifier = selectedLauncherIdentifier
        self.launchStyle = launchStyle
        self.useCustomWorkingDirectory = useCustomWorkingDirectory
        self.ignoresPersistentStateOnLaunch = ignoresPersistentStateOnLaunch
        self.debugDocumentVersioning = debugDocumentVersioning
        self.debugServiceExtension = debugServiceExtension
        self.allowLocationSimulation = allowLocationSimulation
        self.buildableProductRunnable = buildableProductRunnable
        self.commandLineArguments = commandLineArguments
        self.environmentVariables = environmentVariables
    }
}

public struct XcodeSchemeProfileAction: Sendable {
    public let buildConfiguration: String?
    public let shouldUseLaunchSchemeArgsEnv: Bool
    public let savedToolIdentifier: String?
    public let useCustomWorkingDirectory: Bool
    public let debugDocumentVersioning: Bool
    public let buildableProductRunnable: XcodeSchemeBuildableProductRunnable?

    public init(
        buildConfiguration: String? = nil,
        shouldUseLaunchSchemeArgsEnv: Bool = true,
        savedToolIdentifier: String? = nil,
        useCustomWorkingDirectory: Bool = false,
        debugDocumentVersioning: Bool = false,
        buildableProductRunnable: XcodeSchemeBuildableProductRunnable? = nil
    ) {
        self.buildConfiguration = buildConfiguration
        self.shouldUseLaunchSchemeArgsEnv = shouldUseLaunchSchemeArgsEnv
        self.savedToolIdentifier = savedToolIdentifier
        self.useCustomWorkingDirectory = useCustomWorkingDirectory
        self.debugDocumentVersioning = debugDocumentVersioning
        self.buildableProductRunnable = buildableProductRunnable
    }
}

public struct XcodeSchemeAnalyzeAction: Sendable {
    public let buildConfiguration: String?

    public init(buildConfiguration: String? = nil) {
        self.buildConfiguration = buildConfiguration
    }
}

public struct XcodeSchemeArchiveAction: Sendable {
    public let buildConfiguration: String?
    public let revealArchiveInOrganizer: Bool

    public init(buildConfiguration: String? = nil, revealArchiveInOrganizer: Bool = true) {
        self.buildConfiguration = buildConfiguration
        self.revealArchiveInOrganizer = revealArchiveInOrganizer
    }
}

// MARK: - Main Scheme Model

public struct XcodeSchemeInfo: Sendable {
    public let name: String
    public let lastUpgradeVersion: String?
    public let version: String?
    public let buildAction: XcodeSchemeBuildAction?
    public let testAction: XcodeSchemeTestAction?
    public let launchAction: XcodeSchemeLaunchAction?
    public let profileAction: XcodeSchemeProfileAction?
    public let analyzeAction: XcodeSchemeAnalyzeAction?
    public let archiveAction: XcodeSchemeArchiveAction?

    public init(
        name: String,
        lastUpgradeVersion: String? = nil,
        version: String? = nil,
        buildAction: XcodeSchemeBuildAction? = nil,
        testAction: XcodeSchemeTestAction? = nil,
        launchAction: XcodeSchemeLaunchAction? = nil,
        profileAction: XcodeSchemeProfileAction? = nil,
        analyzeAction: XcodeSchemeAnalyzeAction? = nil,
        archiveAction: XcodeSchemeArchiveAction? = nil
    ) {
        self.name = name
        self.lastUpgradeVersion = lastUpgradeVersion
        self.version = version
        self.buildAction = buildAction
        self.testAction = testAction
        self.launchAction = launchAction
        self.profileAction = profileAction
        self.analyzeAction = analyzeAction
        self.archiveAction = archiveAction
    }

    // Convenience initializer for backward compatibility
    public init(
        name: String,
        configuration: String? = nil,
        buildableTargets: [XcodeSchemeBuildActionEntry],
        testableTargets: [XcodeSchemeBuildActionEntry] = []
    ) {
        self.name = name
        self.lastUpgradeVersion = nil
        self.version = nil

        // Create BuildAction from buildableTargets
        self.buildAction = XcodeSchemeBuildAction(
            parallelizeBuildables: true,
            buildImplicitDependencies: true,
            buildActionEntries: buildableTargets
        )

        // Create TestAction if we have testable targets
        if !testableTargets.isEmpty {
            let testables = testableTargets.map { target in
                XcodeSchemeTestableReference(skipped: false, buildableReference: target.buildableReference)
            }
            self.testAction = XcodeSchemeTestAction(
                buildConfiguration: configuration,
                testables: testables
            )
        } else {
            self.testAction = nil
        }

        // Create LaunchAction if we have a configuration
        if let configuration {
            self.launchAction = XcodeSchemeLaunchAction(buildConfiguration: configuration)
        } else {
            self.launchAction = nil
        }

        self.profileAction = nil
        self.analyzeAction = nil
        self.archiveAction = nil
    }
}

// MARK: - BSP Extensions

public extension XcodeSchemeBuildActionEntry {
    // Convenience properties for BSP integration
    var targetName: String {
        buildableReference.blueprintName
    }

    var blueprintIdentifier: String {
        buildableReference.blueprintIdentifier
    }

    var buildableName: String? {
        buildableReference.buildableName
    }

    var referencedContainer: String? {
        buildableReference.referencedContainer
    }

    var buildableIdentifier: String? {
        buildableReference.buildableIdentifier
    }
}

public extension XcodeSchemeInfo {
    // Computed Properties for BSP integration
    var configuration: String? {
        launchAction?.buildConfiguration ??
            testAction?.buildConfiguration ??
            profileAction?.buildConfiguration ??
            analyzeAction?.buildConfiguration ??
            archiveAction?.buildConfiguration
    }

    var buildableTargets: [XcodeSchemeBuildActionEntry] {
        buildAction?.buildActionEntries ?? []
    }

    var testableTargets: [XcodeSchemeBuildActionEntry] {
        // First try to get testables from TestAction
        if let testables = testAction?.testables, !testables.isEmpty {
            testables.compactMap { testable in
                if testable.skipped {
                    return nil
                }
                return XcodeSchemeBuildActionEntry(
                    buildForTesting: true,
                    buildForRunning: false,
                    buildForProfiling: false,
                    buildForArchiving: false,
                    buildForAnalyzing: false,
                    buildableReference: testable.buildableReference
                )
            }
        } else {
            // Fallback to BuildAction entries with buildForTesting=true and NOT the main runnable target
            buildableTargets.filter { target in
                target
                    .buildForTesting &&
                    (!target.buildForRunning || target.buildableName?.hasSuffix("Tests.xctest") == true)
            }
        }
    }

    var testTargets: [XcodeSchemeBuildActionEntry] {
        testableTargets
    }

    var runTargets: [XcodeSchemeBuildActionEntry] {
        buildableTargets.filter(\.buildForRunning)
    }

    var firstBuildableTarget: XcodeSchemeBuildActionEntry? {
        runTargets.first ?? buildableTargets.first
    }

    var targets: [XcodeSchemeBuildActionEntry] {
        var allTargets: [XcodeSchemeBuildActionEntry] = []
        var seenIdentifiers: Set<String> = []

        // Add buildable targets first
        for target in buildableTargets where !seenIdentifiers.contains(target.blueprintIdentifier) {
            allTargets.append(target)
            seenIdentifiers.insert(target.blueprintIdentifier)
        }

        // Add testable targets, avoiding duplicates
        for target in testableTargets where !seenIdentifiers.contains(target.blueprintIdentifier) {
            allTargets.append(target)
            seenIdentifiers.insert(target.blueprintIdentifier)
        }

        return allTargets
    }

    var enabledArguments: [String] {
        launchAction?.commandLineArguments.compactMap { arg in
            arg.isEnabled ? arg.argument : nil
        } ?? []
    }

    var enabledEnvironmentVariables: [String: String] {
        var env: [String: String] = [:]
        launchAction?.environmentVariables.forEach { envVar in
            if envVar.isEnabled {
                env[envVar.key] = envVar.value
            }
        }
        return env
    }

    var runConfiguration: String? {
        launchAction?.buildConfiguration ?? configuration
    }

    var testConfiguration: String? {
        testAction?.buildConfiguration ?? configuration
    }
}

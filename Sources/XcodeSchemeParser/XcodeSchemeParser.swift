//
//  XcodeSchemeParser.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger
import SwiftyXMLParser

// swiftlint:disable:next type_body_length
public struct XcodeSchemeParser: Sendable {
    public init() {}

    /// Parse a scheme from a file URL
    public func parseScheme(at schemeURL: URL) throws -> XcodeSchemeInfo {
        let xmlData = try Data(contentsOf: schemeURL)
        let schemeName = schemeURL.deletingPathExtension().lastPathComponent
        return try parseScheme(data: xmlData, name: schemeName)
    }

    /// Parse a scheme from data with specified name
    public func parseScheme(data: Data, name: String) throws -> XcodeSchemeInfo {
        let xml = XML.parse(data)
        let schemeAccessor = xml["Scheme"]
        guard schemeAccessor.error == nil else {
            throw XcodeSchemeError.dataParsingError("No Scheme element found in scheme data")
        }

        return try parseScheme(schemeAccessor, name: name)
    }

    // MARK: - Private Parsing Methods

    private func parseScheme(_ schemeAccessor: XML.Accessor, name: String) throws -> XcodeSchemeInfo {
        let lastUpgradeVersion = schemeAccessor.attributes["LastUpgradeVersion"]
        let version = schemeAccessor.attributes["version"]

        let buildAction = parseBuildAction(from: schemeAccessor["BuildAction"])
        let testAction = parseTestAction(from: schemeAccessor["TestAction"])
        let launchAction = parseLaunchAction(from: schemeAccessor["LaunchAction"])
        let profileAction = parseProfileAction(from: schemeAccessor["ProfileAction"])
        let analyzeAction = parseAnalyzeAction(from: schemeAccessor["AnalyzeAction"])
        let archiveAction = parseArchiveAction(from: schemeAccessor["ArchiveAction"])

        return XcodeSchemeInfo(
            name: name,
            lastUpgradeVersion: lastUpgradeVersion,
            version: version,
            buildAction: buildAction,
            testAction: testAction,
            launchAction: launchAction,
            profileAction: profileAction,
            analyzeAction: analyzeAction,
            archiveAction: archiveAction
        )
    }

    // MARK: - Action Parsers

    private func parseBuildAction(from accessor: XML.Accessor) -> XcodeSchemeBuildAction? {
        guard accessor.error == nil else { return nil }

        let parallelizeBuildables = accessor.attributes["parallelizeBuildables"] == "YES"
        let buildImplicitDependencies = accessor.attributes["buildImplicitDependencies"] == "YES"

        let buildActionEntries = parseBuildActionEntries(from: accessor["BuildActionEntries"])

        return XcodeSchemeBuildAction(
            parallelizeBuildables: parallelizeBuildables,
            buildImplicitDependencies: buildImplicitDependencies,
            buildActionEntries: buildActionEntries
        )
    }

    private func parseTestAction(from accessor: XML.Accessor) -> XcodeSchemeTestAction? {
        guard accessor.error == nil else { return nil }

        let buildConfiguration = accessor.attributes["buildConfiguration"]
        let selectedDebuggerIdentifier = accessor.attributes["selectedDebuggerIdentifier"]
        let selectedLauncherIdentifier = accessor.attributes["selectedLauncherIdentifier"]
        let shouldUseLaunchSchemeArgsEnv = accessor.attributes["shouldUseLaunchSchemeArgsEnv"] == "YES"

        let testables = parseTestables(from: accessor["Testables"])

        return XcodeSchemeTestAction(
            buildConfiguration: buildConfiguration,
            selectedDebuggerIdentifier: selectedDebuggerIdentifier,
            selectedLauncherIdentifier: selectedLauncherIdentifier,
            shouldUseLaunchSchemeArgsEnv: shouldUseLaunchSchemeArgsEnv,
            testables: testables
        )
    }

    private func parseLaunchAction(from accessor: XML.Accessor) -> XcodeSchemeLaunchAction? {
        guard accessor.error == nil else { return nil }

        let buildConfiguration = accessor.attributes["buildConfiguration"]
        let selectedDebuggerIdentifier = accessor.attributes["selectedDebuggerIdentifier"]
        let selectedLauncherIdentifier = accessor.attributes["selectedLauncherIdentifier"]
        let launchStyle = accessor.attributes["launchStyle"]
        let useCustomWorkingDirectory = accessor.attributes["useCustomWorkingDirectory"] == "YES"
        let ignoresPersistentStateOnLaunch = accessor.attributes["ignoresPersistentStateOnLaunch"] == "YES"
        let debugDocumentVersioning = accessor.attributes["debugDocumentVersioning"] == "YES"
        let debugServiceExtension = accessor.attributes["debugServiceExtension"]
        let allowLocationSimulation = accessor.attributes["allowLocationSimulation"] == "YES"

        let buildableProductRunnable = parseBuildableProductRunnable(from: accessor["BuildableProductRunnable"])
        let commandLineArguments = parseCommandLineArguments(from: accessor["CommandLineArguments"])
        let environmentVariables = parseEnvironmentVariables(from: accessor["EnvironmentVariables"])

        return XcodeSchemeLaunchAction(
            buildConfiguration: buildConfiguration,
            selectedDebuggerIdentifier: selectedDebuggerIdentifier,
            selectedLauncherIdentifier: selectedLauncherIdentifier,
            launchStyle: launchStyle,
            useCustomWorkingDirectory: useCustomWorkingDirectory,
            ignoresPersistentStateOnLaunch: ignoresPersistentStateOnLaunch,
            debugDocumentVersioning: debugDocumentVersioning,
            debugServiceExtension: debugServiceExtension,
            allowLocationSimulation: allowLocationSimulation,
            buildableProductRunnable: buildableProductRunnable,
            commandLineArguments: commandLineArguments,
            environmentVariables: environmentVariables
        )
    }

    private func parseProfileAction(from accessor: XML.Accessor) -> XcodeSchemeProfileAction? {
        guard accessor.error == nil else { return nil }

        let buildConfiguration = accessor.attributes["buildConfiguration"]
        let shouldUseLaunchSchemeArgsEnv = accessor.attributes["shouldUseLaunchSchemeArgsEnv"] == "YES"
        let savedToolIdentifier = accessor.attributes["savedToolIdentifier"]
        let useCustomWorkingDirectory = accessor.attributes["useCustomWorkingDirectory"] == "YES"
        let debugDocumentVersioning = accessor.attributes["debugDocumentVersioning"] == "YES"

        let buildableProductRunnable = parseBuildableProductRunnable(from: accessor["BuildableProductRunnable"])

        return XcodeSchemeProfileAction(
            buildConfiguration: buildConfiguration,
            shouldUseLaunchSchemeArgsEnv: shouldUseLaunchSchemeArgsEnv,
            savedToolIdentifier: savedToolIdentifier,
            useCustomWorkingDirectory: useCustomWorkingDirectory,
            debugDocumentVersioning: debugDocumentVersioning,
            buildableProductRunnable: buildableProductRunnable
        )
    }

    private func parseAnalyzeAction(from accessor: XML.Accessor) -> XcodeSchemeAnalyzeAction? {
        guard accessor.error == nil else { return nil }

        let buildConfiguration = accessor.attributes["buildConfiguration"]

        return XcodeSchemeAnalyzeAction(buildConfiguration: buildConfiguration)
    }

    private func parseArchiveAction(from accessor: XML.Accessor) -> XcodeSchemeArchiveAction? {
        guard accessor.error == nil else { return nil }

        let buildConfiguration = accessor.attributes["buildConfiguration"]
        let revealArchiveInOrganizer = accessor.attributes["revealArchiveInOrganizer"] == "YES"

        return XcodeSchemeArchiveAction(
            buildConfiguration: buildConfiguration,
            revealArchiveInOrganizer: revealArchiveInOrganizer
        )
    }

    // MARK: - Sub-element Parsers

    private func parseBuildActionEntries(from accessor: XML.Accessor) -> [XcodeSchemeTargetInfo] {
        guard accessor.error == nil else { return [] }

        var entries: [XcodeSchemeTargetInfo] = []

        var index = 0
        while true {
            let entry = accessor["BuildActionEntry", index]
            if entry.error != nil { break }

            if let targetInfo = parseBuildActionEntry(entry) {
                entries.append(targetInfo)
            }
            index += 1
        }

        if entries.isEmpty {
            let singleEntry = accessor["BuildActionEntry"]
            if let targetInfo = parseBuildActionEntry(singleEntry) {
                entries.append(targetInfo)
            }
        }

        return entries
    }

    private func parseBuildActionEntry(_ accessor: XML.Accessor) -> XcodeSchemeTargetInfo? {
        let buildForTesting = accessor.attributes["buildForTesting"] == "YES"
        let buildForRunning = accessor.attributes["buildForRunning"] == "YES"
        let buildForProfiling = accessor.attributes["buildForProfiling"] == "YES"
        let buildForArchiving = accessor.attributes["buildForArchiving"] == "YES"
        let buildForAnalyzing = accessor.attributes["buildForAnalyzing"] == "YES"

        guard let buildableReference = parseBuildableReference(from: accessor["BuildableReference"]) else {
            return nil
        }

        return XcodeSchemeTargetInfo(
            buildForTesting: buildForTesting,
            buildForRunning: buildForRunning,
            buildForProfiling: buildForProfiling,
            buildForArchiving: buildForArchiving,
            buildForAnalyzing: buildForAnalyzing,
            buildableReference: buildableReference
        )
    }

    private func parseTestables(from accessor: XML.Accessor) -> [XcodeSchemeTestableReference] {
        guard accessor.error == nil else { return [] }

        var testables: [XcodeSchemeTestableReference] = []

        var index = 0
        while true {
            let testableRef = accessor["TestableReference", index]
            if testableRef.error != nil { break }

            if let testableReference = parseTestableReference(testableRef) {
                testables.append(testableReference)
            }
            index += 1
        }

        if testables.isEmpty {
            let singleTestable = accessor["TestableReference"]
            if let testableReference = parseTestableReference(singleTestable) {
                testables.append(testableReference)
            }
        }

        return testables
    }

    private func parseTestableReference(_ accessor: XML.Accessor) -> XcodeSchemeTestableReference? {
        let skipped = accessor.attributes["skipped"] == "YES"

        guard let buildableReference = parseBuildableReference(from: accessor["BuildableReference"]) else {
            return nil
        }

        return XcodeSchemeTestableReference(
            skipped: skipped,
            buildableReference: buildableReference
        )
    }

    private func parseBuildableProductRunnable(from accessor: XML.Accessor) -> XcodeSchemeBuildableProductRunnable? {
        guard accessor.error == nil else { return nil }

        let runnableDebuggingMode = accessor.attributes["runnableDebuggingMode"]

        guard let buildableReference = parseBuildableReference(from: accessor["BuildableReference"]) else {
            return nil
        }

        return XcodeSchemeBuildableProductRunnable(
            runnableDebuggingMode: runnableDebuggingMode,
            buildableReference: buildableReference
        )
    }

    private func parseBuildableReference(from accessor: XML.Accessor) -> XcodeSchemeBuildableReference? {
        guard accessor.error == nil,
              let blueprintName = accessor.attributes["BlueprintName"],
              let blueprintIdentifier = accessor.attributes["BlueprintIdentifier"] else {
            return nil
        }

        let buildableIdentifier = accessor.attributes["BuildableIdentifier"] ?? "primary"
        let buildableName = accessor.attributes["BuildableName"]
        let referencedContainer = accessor.attributes["ReferencedContainer"]

        return XcodeSchemeBuildableReference(
            buildableIdentifier: buildableIdentifier,
            blueprintIdentifier: blueprintIdentifier,
            buildableName: buildableName,
            blueprintName: blueprintName,
            referencedContainer: referencedContainer
        )
    }

    private func parseCommandLineArguments(from accessor: XML.Accessor) -> [XcodeSchemeCommandLineArgument] {
        guard accessor.error == nil else { return [] }

        var arguments: [XcodeSchemeCommandLineArgument] = []

        var index = 0
        while true {
            let argElement = accessor["CommandLineArgument", index]
            if argElement.error != nil { break }

            if let argument = argElement.attributes["argument"] {
                let isEnabled = argElement.attributes["isEnabled"] != "NO"
                arguments.append(XcodeSchemeCommandLineArgument(argument: argument, isEnabled: isEnabled))
            }

            index += 1
        }

        if arguments.isEmpty {
            let singleArg = accessor["CommandLineArgument"]
            if let argument = singleArg.attributes["argument"] {
                let isEnabled = singleArg.attributes["isEnabled"] != "NO"
                arguments.append(XcodeSchemeCommandLineArgument(argument: argument, isEnabled: isEnabled))
            }
        }

        return arguments
    }

    private func parseEnvironmentVariables(from accessor: XML.Accessor) -> [XcodeSchemeEnvironmentVariable] {
        guard accessor.error == nil else { return [] }

        var variables: [XcodeSchemeEnvironmentVariable] = []

        var index = 0
        while true {
            let varElement = accessor["EnvironmentVariable", index]
            if varElement.error != nil { break }

            if let key = varElement.attributes["key"],
               let value = varElement.attributes["value"] {
                let isEnabled = varElement.attributes["isEnabled"] != "NO"
                variables.append(XcodeSchemeEnvironmentVariable(key: key, value: value, isEnabled: isEnabled))
            }

            index += 1
        }

        if variables.isEmpty {
            let singleVar = accessor["EnvironmentVariable"]
            if let key = singleVar.attributes["key"],
               let value = singleVar.attributes["value"] {
                let isEnabled = singleVar.attributes["isEnabled"] != "NO"
                variables.append(XcodeSchemeEnvironmentVariable(key: key, value: value, isEnabled: isEnabled))
            }
        }

        return variables
    }
}

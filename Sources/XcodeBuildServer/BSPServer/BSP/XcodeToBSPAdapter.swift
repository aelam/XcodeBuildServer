//
//  XcodeToBSPAdapter.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

/// Adapter for converting Xcode project information to BSP BuildTarget objects
public actor XcodeToBSPAdapter {
    private let xcodeProjectInfo: XcodeProjectInfo
    private let xcodeToolchain: XcodeToolchain

    public init(
        xcodeProjectInfo: XcodeProjectInfo,
        xcodeToolchain: XcodeToolchain
    ) {
        self.xcodeProjectInfo = xcodeProjectInfo
        self.xcodeToolchain = xcodeToolchain
    }

    /// Create all BuildTarget objects for BSP from the current project
    public func createBuildTargets() async throws -> [BuildTarget] {
        var buildTargets: [BuildTarget] = []

        // Create BuildTargets based on what's available in buildSettingsForIndex
        guard let buildSettingsForIndex = xcodeProjectInfo.buildSettingsForIndex else {
            logger.warning("No buildSettingsForIndex available, cannot create build targets")
            return []
        }

        logger.debug("Creating BuildTargets from \(buildSettingsForIndex.count) targets in buildSettingsForIndex")

        for (targetIdentifier, _) in buildSettingsForIndex {
            logger.debug("Processing target key: \(targetIdentifier)")

            // Extract target name from the key (format: xcode:///path/to/project.xcodeproj/TargetName)

            let buildTarget = await createBuildTarget(
                targetIdentifier: targetIdentifier,
                projectBasicInfo: xcodeProjectInfo
            )
            buildTargets.append(buildTarget)
        }

        logger.info("Created \(buildTargets.count) BuildTargets from buildSettingsForIndex")
        return buildTargets
    }

    /// Create a single BuildTarget from buildSettingsForIndex
    private func createBuildTarget(
        targetIdentifier: String, // xcode:///path/to/project.xcodeproj/TargetName
        projectBasicInfo: XcodeProjectInfo
    ) async -> BuildTarget {
        // Create BSP target identifier using the targetKey directly
        // Convert to xcode:// URI format with default scheme
        let buildTargetIdentifier = createBuildTargetIdentifier(from: targetIdentifier)
        let targetName = buildTargetIdentifier.xcodeTargetName

        let baseDirectory = try? URI(string: projectBasicInfo.rootURL.absoluteString)
        let displayName = targetName // Just use target name without scheme
        let tags = classifyTargetByName(targetName)
        let languages = await detectLanguagesForTarget(targetName)
        let capabilities = createCapabilitiesForTarget(targetName)
        let sourceKitData = await createSourceKitData()

        return BuildTarget(
            id: buildTargetIdentifier,
            displayName: displayName,
            baseDirectory: baseDirectory,
            tags: tags,
            languageIds: languages,
            dependencies: [], // TODO: Extract dependencies from build settings
            capabilities: capabilities,
            dataKind: .sourceKit,
            data: sourceKitData?.encodeToLSPAny()
        )
    }

    /// Convert string identifier to BuildTargetIdentifier
    private func createBuildTargetIdentifier(from identifier: String) -> BuildTargetIdentifier {
        if let uri = try? URI(string: identifier) {
            return BuildTargetIdentifier(uri: uri)
        } else {
            // swiftlint:disable:next force_try
            let fallbackURI = try! URI(string: "xcode:///unknown/unknown/unknown")
            return BuildTargetIdentifier(uri: fallbackURI)
        }
    }

    /// Classify target into BuildTargetTag categories based on scheme configuration
    private func classifyTarget(_ targetInfo: XcodeSchemeTargetInfo) -> [BuildTargetTag] {
        var tags: [BuildTargetTag] = []

        if targetInfo.targetName.contains("UITest") {
            tags.append(.integrationTest)
        } else if targetInfo.buildForTesting, !targetInfo.buildForRunning {
            // Pure test target (only builds for testing)
            tags.append(.test)
        } else if targetInfo.buildForRunning {
            // Runnable target (application or executable)
            tags.append(.application)
        } else {
            // Default to library for targets that are neither test nor runnable
            tags.append(.library)
        }

        return tags
    }

    /// Map language strings to Language enum
    private func mapLanguages(from languageStrings: Set<String>) -> [Language] {
        languageStrings.compactMap { languageString in
            switch languageString {
            case "swift":
                .swift
            case "objective-c":
                .objective_c
            case "c":
                .c
            case "cpp":
                .cpp
            default:
                nil
            }
        }
    }

    /// Detect programming languages used by a target
    private func detectLanguages(for targetInfo: XcodeSchemeTargetInfo, scheme: String) async -> [Language] {
        // For now, detect languages based on target name patterns and common conventions
        // This could be enhanced by analyzing source files or build settings in the future

        var languages: Set<String> = []

        // Most iOS/macOS projects use Swift
        languages.insert("swift")

        // Add Objective-C for targets that might use it (legacy code, bridging, etc.)
        // This is a heuristic - in practice, you might want to scan source files
        if targetInfo.targetName.contains("ObjC") ||
            targetInfo.targetName.contains("Legacy") {
            languages.insert("objective-c")
        }

        // For test targets, they typically use the same languages as main targets
        if targetInfo.targetName.contains("Test") {
            languages.insert("swift")
        }

        return mapLanguages(from: languages)
    }

    /// Create capabilities for BSP target based on scheme configuration
    private func createCapabilities(for targetInfo: XcodeSchemeTargetInfo) -> BuildTargetCapabilities {
        BuildTargetCapabilities(
            canCompile: true, // All Xcode targets can compile
            canTest: targetInfo.buildForTesting,
            canRun: targetInfo.buildForRunning,
            canDebug: true // Xcode supports debugging for all targets
        )
    }

    /// Create SourceKit data for the target
    private func createSourceKitData() async -> SourceKitBuildTarget? {
        guard let installation = await xcodeToolchain.getSelectedInstallation() else {
            return nil
        }

        // toolchain应该指向包含'usr'目录的toolchain目录
        // 对于iOS/macOS项目，XcodeDefault.xctoolchain包含所有平台的工具
        let toolchainPath = installation.path
            .appendingPathComponent("Contents/Developer/Toolchains/XcodeDefault.xctoolchain")

        // 验证toolchain路径是否存在
        guard FileManager.default.fileExists(atPath: toolchainPath.path) else {
            logger.warning("Toolchain not found at: \(toolchainPath.path)")
            return SourceKitBuildTarget(toolchain: nil)
        }

        let toolchainURI = try? URI(string: toolchainPath.absoluteString)
        return SourceKitBuildTarget(toolchain: toolchainURI)
    }

    /// Extract target name from buildSettingsForIndex key
    /// Key format: "/path/to/project.xcodeproj/TargetName"
    private func extractTargetNameFromKey(_ key: String) -> String {
        (key as NSString).lastPathComponent
    }

    /// Classify target based on name patterns
    private func classifyTargetByName(_ targetName: String) -> [BuildTargetTag] {
        var tags: [BuildTargetTag] = []

        if targetName.contains("UITest") {
            tags.append(.integrationTest)
        } else if targetName.contains("Test") {
            tags.append(.test)
        } else {
            tags.append(.application)
        }

        return tags
    }

    /// Detect languages for a target based on name
    private func detectLanguagesForTarget(_ targetName: String) async -> [Language] {
        // For now, assume Swift for all targets
        // This could be enhanced by analyzing build settings
        [.swift]
    }

    /// Create capabilities for a target based on name
    private func createCapabilitiesForTarget(_ targetName: String) -> BuildTargetCapabilities {
        let isTestTarget = targetName.contains("Test")

        return BuildTargetCapabilities(
            canCompile: true,
            canTest: isTestTarget,
            canRun: !isTestTarget,
            canDebug: true
        )
    }
}

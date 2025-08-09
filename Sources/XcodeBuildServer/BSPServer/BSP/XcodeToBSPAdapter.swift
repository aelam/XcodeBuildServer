//
//  XcodeToBSPAdapter.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

/// Adapter for converting Xcode project information to BSP BuildTarget objects
public actor XcodeToBSPAdapter {
    private let projectManager: XcodeProjectManager

    public init(projectManager: XcodeProjectManager) {
        self.projectManager = projectManager
    }

    /// Create all BuildTarget objects for BSP from the current project
    public func createBuildTargets() async throws -> [BuildTarget] {
        let currentProject = try await getCurrentProject()
        var buildTargets: [BuildTarget] = []

        // Create one BSP BuildTarget for each scheme-target combination
        for schemeInfo in currentProject.schemeInfoList {
            for schemeTargetInfo in schemeInfo.targets {
                let buildTarget = await createBuildTarget(
                    from: schemeTargetInfo,
                    scheme: schemeInfo,
                    projectBasicInfo: currentProject
                )
                buildTargets.append(buildTarget)
            }
        }

        return buildTargets
    }

    /// Get current project info
    private func getCurrentProject() async throws -> XcodeProjectBasicInfo {
        guard let currentProject = await projectManager.currentProjectInfo else {
            throw XcodeProjectError.invalidConfig("Project not loaded. Call loadProjectBasicInfo() first.")
        }
        return currentProject
    }

    /// Create a single BuildTarget for a specific scheme-target combination
    private func createBuildTarget(
        from targetInfo: XcodeSchemeTargetInfo,
        scheme: XcodeSchemeInfo,
        projectBasicInfo: XcodeProjectBasicInfo
    ) async -> BuildTarget {
        // Create BSP target identifier for this specific scheme-target combination
        let targetIdentifier = createBSPTargetIdentifier(
            targetName: targetInfo.targetName,
            primaryScheme: scheme.name,
            projectBasicInfo: projectBasicInfo
        )
        let targetID = createBuildTargetIdentifier(from: targetIdentifier)

        let baseDirectory = try? URI(string: projectBasicInfo.rootURL.absoluteString)
        let displayName = "\(scheme.name)/\(targetInfo.targetName)"
        let tags = classifyTarget(targetInfo)
        let languages: [Language] = [] // TODO: Get languages from target build settings
        let capabilities = createCapabilities(for: targetInfo)
        let sourceKitData = await createSourceKitData()

        return BuildTarget(
            id: targetID,
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
    

    /// Create BSP target identifier string from XcodeProjectBasicInfo and target details
    private func createBSPTargetIdentifier(
        targetName: String,
        primaryScheme: String,
        projectBasicInfo: XcodeProjectBasicInfo
    ) -> String {
        "xcode:///\(projectBasicInfo.projectLocation.name)/\(primaryScheme)/\(targetName)"
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
        } else if targetInfo.buildForTesting && !targetInfo.buildForRunning {
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

    /// Create capabilities for BSP target based on scheme configuration
    private func createCapabilities(for targetInfo: XcodeSchemeTargetInfo) -> BuildTargetCapabilities {
        return BuildTargetCapabilities(
            canCompile: true, // All Xcode targets can compile
            canTest: targetInfo.buildForTesting,
            canRun: targetInfo.buildForRunning,
            canDebug: true // Xcode supports debugging for all targets
        )
    }

    /// Create SourceKit data for the target
    private func createSourceKitData() async -> SourceKitBuildTarget? {
        let toolchain = await projectManager.getToolchain()
        guard let installation = await toolchain.getSelectedInstallation() else {
            return nil
        }

        let toolchainURI = try? URI(string: installation.path.absoluteString)
        return SourceKitBuildTarget(toolchain: toolchainURI)
    }
}

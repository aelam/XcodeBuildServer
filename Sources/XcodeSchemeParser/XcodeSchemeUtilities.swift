//
//  XcodeSchemeUtilities.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

/// Utility functions for working with Xcode schemes
public extension XcodeSchemeLoader {
    /// Get all runnable target names from all schemes
    func getAllRunnableTargets(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var runnableTargets: Set<String> = []

        for scheme in schemes {
            for target in scheme.runTargets {
                runnableTargets.insert(target.targetName)
            }
        }

        return runnableTargets
    }

    /// Get all testable target names from all schemes
    func getAllTestableTargets(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var testableTargets: Set<String> = []

        for scheme in schemes {
            for target in scheme.testTargets {
                testableTargets.insert(target.targetName)
            }
        }

        return testableTargets
    }

    /// Get all unique target names from all schemes
    func getAllTargetNames(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var targets: Set<String> = []

        for scheme in schemes {
            for target in scheme.targets {
                targets.insert(target.targetName)
            }
        }

        return targets
    }

    /// Get all buildable target names from all schemes
    func getAllBuildableTargets(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var buildableTargets: Set<String> = []

        for scheme in schemes {
            for target in scheme.buildableTargets {
                buildableTargets.insert(target.targetName)
            }
        }

        return buildableTargets
    }

    /// Get launch configurations for all schemes
    func getLaunchConfigurations(from schemes: [XcodeSchemeInfo]) -> [String: String] {
        var configurations: [String: String] = [:]

        for scheme in schemes {
            if let launchConfig = scheme.runConfiguration {
                configurations[scheme.name] = launchConfig
            }
        }

        return configurations
    }

    /// Get test configurations for all schemes
    func getTestConfigurations(from schemes: [XcodeSchemeInfo]) -> [String: String] {
        var configurations: [String: String] = [:]

        for scheme in schemes {
            if let testConfig = scheme.testConfiguration {
                configurations[scheme.name] = testConfig
            }
        }

        return configurations
    }

    /// Get all environment variables from launch actions
    func getAllEnvironmentVariables(from schemes: [XcodeSchemeInfo]) -> [String: [String: String]] {
        var allEnvVars: [String: [String: String]] = [:]

        for scheme in schemes {
            let envVars = scheme.enabledEnvironmentVariables
            if !envVars.isEmpty {
                allEnvVars[scheme.name] = envVars
            }
        }

        return allEnvVars
    }

    /// Get all command line arguments from launch actions
    func getAllCommandLineArguments(from schemes: [XcodeSchemeInfo]) -> [String: [String]] {
        var allArgs: [String: [String]] = [:]

        for scheme in schemes {
            let args = scheme.enabledArguments
            if !args.isEmpty {
                allArgs[scheme.name] = args
            }
        }

        return allArgs
    }

    /// Get schemes that contain a specific target
    func getSchemes(containing targetName: String, from schemes: [XcodeSchemeInfo]) -> [XcodeSchemeInfo] {
        schemes.filter { scheme in
            scheme.targets.contains { $0.targetName == targetName }
        }
    }

    /// Get the preferred scheme for a target (prioritizes runnable schemes)
    func getPreferredScheme(for targetName: String, from schemes: [XcodeSchemeInfo]) -> XcodeSchemeInfo? {
        let schemesWithTarget = getSchemes(containing: targetName, from: schemes)

        // Prefer schemes where the target is runnable
        if let runnableScheme = schemesWithTarget.first(where: { scheme in
            scheme.targets.contains { $0.targetName == targetName && $0.buildForRunning }
        }) {
            return runnableScheme
        }

        // Otherwise return the first scheme containing the target
        return schemesWithTarget.first
    }

    /// Validate scheme consistency
    func validateSchemes(_ schemes: [XcodeSchemeInfo]) throws {
        guard !schemes.isEmpty else {
            throw XcodeSchemeError.invalidConfig("No schemes found in project")
        }

        // Validate each scheme has at least one target
        for scheme in schemes where scheme.targets.isEmpty {
            logger.warning("Scheme '\(scheme.name)' has no targets")
        }
    }
}

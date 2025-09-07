// import Foundation

// public enum BuildError: Error, Sendable {
//     case buildFailed(exitCode: Int32, output: String)
// }

// public extension XcodeProjectManager {
//     func compileTarget(
//         targetIdentifier: XcodeTargetIdentifier,
//         configuration: String = "Debug"
//     ) async throws -> XcodeBuildResult {
//         let projectURL = URL(fileURLWithPath: targetIdentifier.projectFilePath)

//         guard
//             let xcodeProjectBaseInfo,
//             let xcodeProj = loadXcodeProjCache(projectURL: projectURL)
//         else {
//             return XcodeBuildResult(output: "", error: "No Xcode project found", exitCode: 1)
//         }

//         let otherXcodeProjs = Set(
//             xcodeProjectBaseInfo.xcodeTargets.map(\.targetIdentifier.projectFilePath)
//         )
//         .filter { $0 != targetIdentifier.projectFilePath }
//         .compactMap { loadXcodeProjCache(projectURL: URL(fileURLWithPath: $0)) }

//         let buildGraph = XcodeBuildGraphResolver(
//             primaryXcodeProj: xcodeProj,
//             additionalXcodeProjs: otherXcodeProjs,
//             mode: .topLevel
//         )
//         let targetIdentifiers = buildGraph.buildOrder(for: targetIdentifier)

//         return try await compileTargetDependencies(
//             targetIdentifiers: targetIdentifiers,
//             configuration: configuration,
//             xcodeProjectBaseInfo: xcodeProjectBaseInfo
//         )
//     }

//     private func compileTargetDependencies(
//         targetIdentifiers: [XcodeTargetIdentifier],
//         configuration: String = "Debug",
//         xcodeProjectBaseInfo: XcodeProjectBaseInfo
//     ) async throws -> XcodeBuildResult {
//         for targetIdentifier in targetIdentifiers {
//             print("Compiling target: \(targetIdentifier.rawValue)")
//             guard let xcodeProj = loadXcodeProjCache(
//                 projectURL: URL(fileURLWithPath: targetIdentifier.projectFilePath)
//             ) else {
//                 throw BuildError.buildFailed(
//                     exitCode: 1,
//                     output: "Xcode project not found at \(targetIdentifier.projectFilePath)"
//                 )
//             }
//             let buildSettings = try BuildSettingResolver(
//                 xcodeInstallation: xcodeProjectBaseInfo.xcodeInstallation,
//                 xcodeGlobalSettings: xcodeProjectBaseInfo.xcodeGlobalSettings,
//                 xcodeProj: xcodeProj,
//                 target: targetIdentifier.targetName,
//                 configuration: configuration
//             ).resolvedBuildSettings

//             var enviromentVariables: [String: String] = [:]
//             enviromentVariables["ARCHS"] = buildSettings["ARCHS"]
//             enviromentVariables["SRCROOT"] = buildSettings["SRCROOT"]
//             enviromentVariables["OBJROOT"] = buildSettings["OBJROOT"]
//             enviromentVariables["SYMROOT"] = buildSettings["SYMROOT"]
//             enviromentVariables["CONFIGURATION_BUILD_DIR"] = buildSettings["CONFIGURATION_BUILD_DIR"]
//             enviromentVariables["PODS_ROOT"] = buildSettings["PODS_ROOT"]
//             enviromentVariables["SKIP_INSTALL"] = "NO" // buildSettings["SKIP_INSTALL"]

//             let customFlags = enviromentVariables.map { key, value in
//                 "\(key)=\(value)"
//             }

//             let result = try await compileSingleTarget(
//                 targetIdentifier: targetIdentifier,
//                 configuration: configuration,
//                 enviromentVariables: [:],
//                 xcodeBuildCustomFlags: customFlags
//             )
//             if result.exitCode != 0 {
//                 throw BuildError.buildFailed(
//                     exitCode: result.exitCode,
//                     output: result.output + "\n" + (result.error ?? "")
//                 )
//             }
//         }

//         print("All targets compiled successfully.")
//         return XcodeBuildResult(output: "Success", error: nil, exitCode: 0)
//     }

//     private func compileSingleTarget(
//         targetIdentifier: XcodeTargetIdentifier,
//         configuration: String = "Debug",
//         enviromentVariables: [String: String] = [:],
//         xcodeBuildCustomFlags: [String] = []
//     ) async throws -> XcodeBuildResult {
//         let options = XcodeBuildOptions(
//             command: .build(
//                 action: .build,
//                 sdk: .iOSSimulator,
//                 destination: nil,
//                 configuration: configuration,
//                 derivedDataPath: nil,
//                 resultBundlePath: nil
//             ),
//             flags: XcodeBuildFlags(),
//             customFlags: xcodeBuildCustomFlags
//         )

//         let commandBuilder = XcodeBuildCommandBuilder()
//         let command = commandBuilder.buildCommand(
//             project: .project(
//                 projectURL: URL(fileURLWithPath: targetIdentifier.projectFilePath),
//                 buildMode: .targets([targetIdentifier.targetName])
//             ),
//             options: options
//         )

//         let result = try await toolchain.executeXcodeBuild(
//             arguments: command,
//             workingDirectory: rootURL,
//             xcodeBuildEnvironments: enviromentVariables
//         )
//         return result
//     }
// }

// ===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// ===----------------------------------------------------------------------===//

/// Build target contains metadata about an artifact (for example library, test, or binary artifact).
/// Using vocabulary of other build tools:
/// - sbt: a build target is a combined project + config. Example:
///   - a regular JVM project with main and test configurations will have 2 build targets, one for main and one for
/// test.
///   - a single configuration in a single project that contains both Java and Scala sources maps to one BuildTarget.
///    - a project with crossScalaVersions 2.11 and 2.12 containing main and test configuration in each will have 4
/// build targets.
///   - a Scala 2.11 and 2.12 cross-built project for Scala.js and the JVM with main and test configurations will have 8
/// build targets.
/// - Pants: a pants target corresponds one-to-one with a BuildTarget
/// - Bazel: a bazel target corresponds one-to-one with a BuildTarget
///
/// The general idea is that the BuildTarget data structure should contain only information that is fast or cheap to
/// compute
public struct BSPBuildTarget: Codable, Hashable, Sendable {
    /// The target’s unique identifier
    public var id: BuildTargetIdentifier

    /// A human readable name for this target.
    /// May be presented in the user interface.
    /// Should be unique if possible.
    /// The id.uri is used if None.
    public var displayName: String?

    /// The directory where this target belongs to. Multiple build targets are
    /// allowed to map to the same base directory, and a build target is not
    /// required to have a base directory. A base directory does not determine the
    /// sources of a target, see `buildTarget/sources`.
    public var baseDirectory: URI?

    /// Free-form string tags to categorize or label this build target.
    /// For example, can be used by the client to:
    /// - customize how the target should be translated into the client's project
    ///   model.
    /// - group together different but related targets in the user interface.
    /// - display icons or colors in the user interface.
    /// Pre-defined tags are listed in `BuildTargetTag` but clients and servers
    /// are free to define new tags for custom purposes.
    public var tags: [BuildTargetTag]

    /// The set of languages that this target contains.
    /// The ID string for each language is defined in the LSP.
    public var languageIds: [Language]

    /// The direct upstream build target dependencies of this build target
    public var dependencies: [BuildTargetIdentifier]

    /// The capabilities of this build target.
    public var capabilities: BuildTargetCapabilities

    /// Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
    public var dataKind: BuildTargetDataKind?

    /// Language-specific metadata about this target.
    /// See ScalaBuildTarget as an example.
    public var data: LSPAny?
}

/// A unique identifier for a target, can use any URI-compatible encoding as long as it is unique within the workspace.
/// Clients should not infer metadata out of the URI structure such as the path or query parameters, use `BuildTarget`
/// instead.
///

/// A list of predefined tags that can be used to categorize build targets.
public struct BuildTargetTag: Codable, Hashable, RawRepresentable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Target contains source code for producing any kind of application, may
    /// have but does not require the `canRun` capability.
    public static let application: Self = .init(rawValue: "application")

    /// Target contains source code to measure performance of a program, may have
    /// but does not require the `canRun` build target capability.
    public static let benchmark: Self = .init(rawValue: "benchmark")

    /// Target contains source code for integration testing purposes, may have
    /// but does not require the `canTest` capability. The difference between
    /// "test" and "integration-test" is that integration tests traditionally run
    /// slower compared to normal tests and require more computing resources to
    /// execute.
    public static let integrationTest: Self = .init(rawValue: "integration-test")

    /// Target contains re-usable functionality for downstream targets. May have
    /// any combination of capabilities.
    public static let library: Self = .init(rawValue: "library")

    /// Actions on the target such as build and test should only be invoked manually
    /// and explicitly. For example, triggering a build on all targets in the workspace
    /// should by default not include this target.
    /// The original motivation to add the "manual" tag comes from a similar functionality
    /// that exists in Bazel, where targets with this tag have to be specified explicitly
    /// on the command line.
    public static let manual: Self = .init(rawValue: "manual")

    /// Target should be ignored by IDEs.
    public static let noIDE: Self = .init(rawValue: "no-ide")

    /// Target contains source code for testing purposes, may have but does not
    /// require the `canTest` capability.
    public static let test: Self = .init(rawValue: "test")

    /// This is a target of a dependency from the project the user opened, eg. a target that builds a SwiftPM
    /// dependency.
    ///
    /// **(BSP Extension)**
    public static let dependency: Self = .init(rawValue: "dependency")

    /// This target only exists to provide compiler arguments for SourceKit-LSP can't be built standalone.
    ///
    /// For example, a SwiftPM package manifest is in a non-buildable target.
    ///
    /// **(BSP Extension)**
    public static let notBuildable: Self = .init(rawValue: "not-buildable")
}

/// Clients can use these capabilities to notify users what BSP endpoints can and cannot be used and why.
public struct BuildTargetCapabilities: Codable, Hashable, Sendable {
    /// This target can be compiled by the BSP server.
    public let canCompile: Bool?

    /// This target can be tested by the BSP server.
    public let canTest: Bool?

    /// This target can be run by the BSP server.
    public let canRun: Bool?

    /// This target can be debugged by the BSP server.
    public let canDebug: Bool?
}

public struct BuildTargetDataKind: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// `data` field must contain a CargoBuildTarget object.
    public static let cargo = BuildTargetDataKind(rawValue: "cargo")

    /// `data` field must contain a CppBuildTarget object.
    public static let cpp = BuildTargetDataKind(rawValue: "cpp")

    /// `data` field must contain a JvmBuildTarget object.
    public static let jvm = BuildTargetDataKind(rawValue: "jvm")

    /// `data` field must contain a PythonBuildTarget object.
    public static let python = BuildTargetDataKind(rawValue: "python")

    /// `data` field must contain a SbtBuildTarget object.
    public static let sbt = BuildTargetDataKind(rawValue: "sbt")

    /// `data` field must contain a ScalaBuildTarget object.
    public static let scala = BuildTargetDataKind(rawValue: "scala")

    /// `data` field must contain a SourceKitBuildTarget object.
    public static let sourceKit = BuildTargetDataKind(rawValue: "sourceKit")
}

public struct SourceKitBuildTarget: LSPAnyCodable, Codable {
    /// The toolchain that should be used to build this target. The URI should point to the directory that contains the
    /// `usr` directory. On macOS, this is typically a bundle ending in `.xctoolchain`. If the toolchain is installed to
    /// `/` on Linux, the toolchain URI would point to `/`.
    ///
    /// If no toolchain is given, SourceKit-LSP will pick a toolchain to use for this target.
    public var toolchain: URI?

    public init(toolchain: URI? = nil) {
        self.toolchain = toolchain
    }

    public init(fromLSPDictionary dictionary: [String: LSPAny]) {
        if case let .string(toolchain) = dictionary[CodingKeys.toolchain.stringValue] {
            self.toolchain = try? URI(string: toolchain)
        }
    }

    public func encodeToLSPAny() -> LSPAny {
        var result: [String: LSPAny] = [:]
        if let toolchain {
            result[CodingKeys.toolchain.stringValue] = .string(toolchain.stringValue)
        }
        return .dictionary(result)
    }
}

public struct BuildTargetIdentifier: Codable, Hashable, Sendable {
    /// The target's Uri
    public var uri: URI

    public init(uri: URI) {
        self.uri = uri
    }
}

public typealias BSPBuildTargetIdentifier = BuildTargetIdentifier

//
//  BuildInitializeRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

import Foundation
import JSONRPCServer

public struct BuildInitializeRequest: ContextualRequestType, Sendable {
    public typealias RequiredContext = BuildServerContext

    public static func method() -> String {
        "build/initialize"
    }

    struct Params: Codable, Sendable {
        struct BuildClientCapabilities: Codable, Sendable {
            let languageIds: [Language]
        }

        let rootUri: String
        let capabilities: BuildClientCapabilities
        let displayName: String?
    }

    let id: JSONRPCID
    let params: Params

    public func handle<Handler: ContextualMessageHandler>(
        handler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        await handler.withContext { context in
            do {
                // Initialize the build server context with the project
                try await context.loadProject(rootURL: URL(filePath: params.rootUri))

                guard
                    let rootURL = URL(string: params.rootUri), // without file://
                    let indexDataStoreURL = await context.indexStoreURL,
                    let indexDatabaseURL = await context.indexDatabaseURL
                else {
                    return JSONRPCErrorResponse(
                        id: id,
                        error: JSONRPCError(
                            code: -32603,
                            message: "Failed to initialize build server: missing index paths"
                        )
                    )
                }

                logger.debug("indexDataStorePath: \(indexDataStoreURL.path, privacy: .public)")
                logger.debug("indexDatabasePath: \(indexDatabaseURL.path, privacy: .public)")
                let globPatternForFileWatch = rootURL.path + "/**/*.swift"
                logger.debug("globPatternForFileWatch: \(globPatternForFileWatch, privacy: .public)")

                // Create server capabilities based on client capabilities
                let capabilities = createServerCapabilities(
                    clientCapabilities: params.capabilities
                )

                return BuildInitializeResponse(
                    jsonrpc: "2.0",
                    id: id,
                    result: .init(
                        capabilities: capabilities,
                        dataKind: "sourceKit",
                        data: .init(
                            indexStorePath: indexDataStoreURL.path,
                            indexDatabasePath: indexDatabaseURL.path,
                            prepareProvider: true,
                            sourceKitOptionsProvider: true,
                            watchers: [
                                FileSystemWatcher(globPattern: globPatternForFileWatch),
                            ]
                        ),
                        rootUri: params.rootUri,
                        bspVersion: "2.0",
                        version: "0.1",
                        displayName: "xcode build server"
                    )
                )
            } catch {
                logger.debug("Error: \(String(describing: error), privacy: .public)")
                return JSONRPCErrorResponse(
                    id: id,
                    error: JSONRPCError(
                        code: -32603,
                        message: "Failed to initialize build server: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    /// Create server capabilities based on client capabilities
    private func createServerCapabilities(
        clientCapabilities: Params.BuildClientCapabilities
    ) -> BuildServerCapabilities {
        let clientLanguages = Set(clientCapabilities.languageIds)
        let supportedLanguages = Array(xcodeBuildServerSupportedLanguages.intersection(clientLanguages))

        // Create capabilities based on supported languages
        let hasLanguages = !supportedLanguages.isEmpty
        return BuildServerCapabilities(
            compileProvider: hasLanguages ? CompileProvider(languageIds: supportedLanguages) : nil,
            testProvider: hasLanguages ? TestProvider(languageIds: supportedLanguages) : nil,
            runProvider: hasLanguages ? RunProvider(languageIds: supportedLanguages) : nil,
            debugProvider: hasLanguages ? DebugProvider(languageIds: supportedLanguages) : nil,
            inverseSourcesProvider: true,
            dependencySourcesProvider: true,
            resourcesProvider: true,
            outputPathsProvider: true,
            buildTargetChangedProvider: true,
            canReload: true
        )
    }
}

struct BuildInitializeResponse: ResponseType {
    struct Result: Codable {
        struct Data: Codable {
            let indexStorePath: String
            let indexDatabasePath: String
            let prepareProvider: Bool?
            let sourceKitOptionsProvider: Bool?
            let watchers: [FileSystemWatcher]
        }

        let capabilities: BuildServerCapabilities
        let dataKind: String
        let data: Data
        let rootUri: String
        let bspVersion: String
        let version: String
        let displayName: String
    }

    let jsonrpc: String
    let id: JSONRPCID?
    let result: Result
}

public struct FileSystemWatcher: Codable, Hashable, Sendable {
    /// The glob pattern to watch.
    public var globPattern: String

    /// The kind of events of interest. If omitted it defaults to
    /// WatchKind.create | WatchKind.change | WatchKind.delete.
    public var kind: WatchKind?

    public init(globPattern: String, kind: WatchKind? = nil) {
        self.globPattern = globPattern
        self.kind = kind
    }
}

public struct WatchKind: OptionSet, Codable, Hashable, Sendable {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let create: WatchKind = .init(rawValue: 1)
    public static let change: WatchKind = .init(rawValue: 2)
    public static let delete: WatchKind = .init(rawValue: 4)
}

public struct BuildServerCapabilities: Codable, Hashable, Sendable {
    /// The languages the server supports compilation via method buildTarget/compile.
    public var compileProvider: CompileProvider?

    /// The languages the server supports test execution via method buildTarget/test
    public var testProvider: TestProvider?

    /// The languages the server supports run via method buildTarget/run
    public var runProvider: RunProvider?

    /// The languages the server supports debugging via method debugSession/start.
    public var debugProvider: DebugProvider?

    /// The server can provide a list of targets that contain a
    /// single text document via the method buildTarget/inverseSources
    public var inverseSourcesProvider: Bool?

    /// The server provides sources for library dependencies
    /// via method buildTarget/dependencySources
    public var dependencySourcesProvider: Bool?

    /// The server provides all the resource dependencies
    /// via method buildTarget/resources
    public var resourcesProvider: Bool?

    /// The server provides all output paths
    /// via method buildTarget/outputPaths
    public var outputPathsProvider: Bool?

    /// The server sends notifications to the client on build
    /// target change events via `buildTarget/didChange`
    public var buildTargetChangedProvider: Bool?

    /// The server can respond to `buildTarget/jvmRunEnvironment` requests with the
    /// necessary information required to launch a Java process to run a main class.
    public var jvmRunEnvironmentProvider: Bool?

    /// The server can respond to `buildTarget/jvmTestEnvironment` requests with the
    /// necessary information required to launch a Java process for testing or
    /// debugging.
    public var jvmTestEnvironmentProvider: Bool?

    /// The server can respond to `workspace/cargoFeaturesState` and
    /// `setCargoFeatures` requests. In other words, supports Cargo Features extension.
    public var cargoFeaturesProvider: Bool?

    /// Reloading the build state through workspace/reload is supported
    public var canReload: Bool?

    /// The server can respond to `buildTarget/jvmCompileClasspath` requests with the
    /// necessary information about the target's classpath.
    public var jvmCompileClasspathProvider: Bool?

    public init(
        compileProvider: CompileProvider? = nil,
        testProvider: TestProvider? = nil,
        runProvider: RunProvider? = nil,
        debugProvider: DebugProvider? = nil,
        inverseSourcesProvider: Bool? = nil,
        dependencySourcesProvider: Bool? = nil,
        resourcesProvider: Bool? = nil,
        outputPathsProvider: Bool? = nil,
        buildTargetChangedProvider: Bool? = nil,
        jvmRunEnvironmentProvider: Bool? = nil,
        jvmTestEnvironmentProvider: Bool? = nil,
        cargoFeaturesProvider: Bool? = nil,
        canReload: Bool? = nil,
        jvmCompileClasspathProvider: Bool? = nil
    ) {
        self.compileProvider = compileProvider
        self.testProvider = testProvider
        self.runProvider = runProvider
        self.debugProvider = debugProvider
        self.inverseSourcesProvider = inverseSourcesProvider
        self.dependencySourcesProvider = dependencySourcesProvider
        self.resourcesProvider = resourcesProvider
        self.outputPathsProvider = outputPathsProvider
        self.buildTargetChangedProvider = buildTargetChangedProvider
        self.jvmRunEnvironmentProvider = jvmRunEnvironmentProvider
        self.jvmTestEnvironmentProvider = jvmTestEnvironmentProvider
        self.cargoFeaturesProvider = cargoFeaturesProvider
        self.canReload = canReload
        self.jvmCompileClasspathProvider = jvmCompileClasspathProvider
    }
}

public struct CompileProvider: Codable, Hashable, Sendable {
    public var languageIds: [Language]

    public init(languageIds: [Language]) {
        self.languageIds = languageIds
    }
}

public struct TestProvider: Codable, Hashable, Sendable {
    public var languageIds: [Language]

    public init(languageIds: [Language]) {
        self.languageIds = languageIds
    }
}

public struct RunProvider: Codable, Hashable, Sendable {
    public var languageIds: [Language]

    public init(languageIds: [Language]) {
        self.languageIds = languageIds
    }
}

public struct DebugProvider: Codable, Hashable, Sendable {
    public var languageIds: [Language]

    public init(languageIds: [Language]) {
        self.languageIds = languageIds
    }
}

//
//  BuildInitializeRequest.swift
//  Created by ST22956 on 2024/11/17.
//

import Foundation
import JSONRPCServer
import Logger

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
        let version: String?
        let bspVersion: String?
    }

    let id: JSONRPCID
    let params: Params

    // MARK: - ContextualRequestType conformance

    // swiftlint:disable:next function_body_length
    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler,
        id: RequestID
    ) async -> ResponseType? where Handler.Context == BuildServerContext {
        logger.debug("BuildInitializeRequest.handle(ContextualMessageHandler) started for request ID: \(id)")
        logger.debug("BuildInitializeRequest params - rootUri: \(params.rootUri)")

        return await contextualHandler.withContext { context -> ResponseType in
            do {
                logger.debug("BuildInitializeRequest: starting loadProject with rootUri: \(self.params.rootUri)")
                // Initialize the build server context with the project
                try await context.loadProject(rootURL: URL(filePath: self.params.rootUri))
                logger.debug("BuildInitializeRequest: loadProject completed successfully")

                logger.debug("BuildInitializeRequest: checking URLs and index paths")
                guard
                    let rootURL = URL(string: self.params.rootUri) // without file://
                else {
                    logger.error("BuildInitializeRequest: failed to create rootURL from: \(self.params.rootUri)")
                    return JSONRPCErrorResponse(
                        id: id,
                        error: JSONRPCError(
                            code: -32603,
                            message: "Failed to initialize build server: invalid root URI"
                        )
                    )
                }
                logger.debug("BuildInitializeRequest: rootURL created successfully: \(rootURL)")

                guard
                    let indexDataStoreURL = try? await context.getIndexStoreURL(),
                    let indexDatabaseURL = try? await context.getIndexDatabaseURL()
                else {
                    logger.error("BuildInitializeRequest: indexStoreURL is nil")
                    return JSONRPCErrorResponse(
                        id: id,
                        error: JSONRPCError(
                            code: -32603,
                            message: "Failed to initialize build server: missing index store URL or index database URL"
                        )
                    )
                }

                logger.debug("BuildInitializeRequest: indexDataStoreURL obtained: \(indexDataStoreURL)")

                logger.info("indexDataStorePath: \(indexDataStoreURL.path)")
                logger.info("indexDatabasePath: \(indexDatabaseURL.path)")
                let globPatternForFileWatch = rootURL.path + "/**/*.swift"
                logger.debug("globPatternForFileWatch: \(globPatternForFileWatch)")

                // Create server capabilities based on client capabilities
                let capabilities = createServerCapabilities(
                    clientCapabilities: self.params.capabilities
                )

                logger.debug("BuildInitializeRequest: creating response")
                let response = BuildInitializeResponse(
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
                        rootUri: self.params.rootUri,
                        bspVersion: "2.2.0",
                        version: "0.1",
                        displayName: "xcode build server"
                    )
                )
                logger.debug("BuildInitializeRequest: response created successfully, returning")
                return response
            } catch {
                logger.error("BuildInitializeRequest: caught exception: \(String(describing: error))")
                let errorResponse = JSONRPCErrorResponse(
                    id: id,
                    error: JSONRPCError(
                        code: -32603,
                        message: "Failed to initialize build server: \(error.localizedDescription)"
                    )
                )
                logger.debug("BuildInitializeRequest: error response created, returning")
                return errorResponse
            }
        }
    }

    /// Create server capabilities based on client capabilities
    private func createServerCapabilities(
        clientCapabilities: Params.BuildClientCapabilities
    ) -> BuildServerCapabilities {
        logger.debug("createServerCapabilities: client languages: \(clientCapabilities.languageIds)")
        let clientLanguages = Set(clientCapabilities.languageIds)
        let supportedLanguages = Array(xcodeBuildServerSupportedLanguages.intersection(clientLanguages))
        logger.debug("createServerCapabilities: supported languages: \(supportedLanguages)")

        // Create capabilities based on supported languages
        let hasLanguages = !supportedLanguages.isEmpty
        logger.debug("createServerCapabilities: hasLanguages: \(hasLanguages)")

        let capabilities = BuildServerCapabilities(
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
        logger.debug("createServerCapabilities: capabilities created successfully")
        return capabilities
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

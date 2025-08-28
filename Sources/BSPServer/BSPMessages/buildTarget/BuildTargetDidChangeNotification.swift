//
//  BuildTargetDidChangeNotification.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/23.
//

import JSONRPCConnection

struct BuildTargetDidChangeNotification: ContextualNotificationType, Sendable {
    typealias RequiredContext = BSPServerService

    static func method() -> String {
        "build/targetDidChange"
    }

    struct Params: Codable, Sendable {
        let changes: [BuildTargetEvent]?
    }

    let jsonrpc: String
    let method: String
    let params: Params

    init(params: Params) {
        self.jsonrpc = "2.0"
        self.method = Self.method()
        self.params = params
    }

    // MARK: - ContextualNotificationType Implementation

    func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler
    ) async throws where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            guard let changes = params.changes else {
                return
            }
            for change in changes {
                handleBuildTargetChange(change)
            }
        }
    }

    private func handleBuildTargetChange(_ change: BuildTargetEvent) {
        // Handle the build target change in the context
        // This could involve updating internal state, notifying observers, etc.
        // The actual implementation will depend on the specifics of the BuildServerContext
        // and how it manages build targets.
    }
}

public struct BuildTargetEvent: Codable, Hashable, Sendable {
    /// The identifier for the changed build target.
    public let target: BuildTargetIdentifier

    /// The kind of change for this build target.
    public let kind: BuildTargetEventKind?

    /// Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
    public let dataKind: BuildTargetEventDataKind?

    /// Any additional metadata about what information changed.
    public let data: LSPAny?
}

public enum BuildTargetEventKind: Int, Codable, Hashable, Sendable {
    /// The build target is new.
    case created = 1

    /// The build target has changed.
    case changed = 2

    /// The build target has been deleted.
    case deleted = 3
}

public struct BuildTargetEventDataKind: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

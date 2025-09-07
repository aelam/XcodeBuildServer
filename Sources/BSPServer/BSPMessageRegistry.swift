//
//  BSPMessageRegistry.swift
//
//  Copyright © 2024 Wang Lun.
//

import JSONRPCConnection

private let requestTypes: [any RequestType.Type] = [
    // build
    BuildInitializeRequest.self,
    BuildShutdownRequest.self,

    // buildTarget
    BuildTargetPrepareRequest.self,
    BuiltTargetSourcesRequest.self,
    BuildTargetCompileRequest.self,

    // textDocument
    TextDocumentRegisterForChangeRequest.self,
    TextDocumentSourceKitOptionsRequest.self,

    // window
    // ...

    // workspace
    WorkspaceBuildTargetsRequest.self,
    WorkspaceWaitForBuildSystemUpdatesRequest.self,
]

private let notificationTypes: [NotificationType.Type] = [
    OnBuildInitializedNotification.self,
    OnBuildExitNotification.self,
    // workspace
    WorkspaceDidChangeWatchedFilesNotification.self,

    // build
    BuildSourceKitOptionsChangedNotification.self,

    // window
    WindowShowMessageNotification.self,

    // $
    CancelRequestNotification.self,
]

public let bspRegistry = MessageRegistry(
    requests: requestTypes,
    notifications: notificationTypes
)

// The Swift Programming Language
// https://docs.swift.org/swift-book

fileprivate let requestTypes: [any RequestType.Type] = [
    // build
    BuildInitializeRequest.self,
    BuildShutdownRequest.self,
    BuildSourceKitOptionsRequest.self,
    
    // buildTarget
    BuildTargetPrepareRequest.self,
    
    // textDocument
    TextDocumentRegisterForChangeRequest.self,
    TextDocumentSourceKitOptionsRequest.self,
    
    // window
    // ...
    
    // workspace
    WorkspaceBuildTargetsRequest.self,
    WorkspaceWaitForBuildSystemUpdatesRequest.self
]

fileprivate let notificationTypes: [NotificationType.Type] = [
    OnBuildInitializedNotification.self,
    OnBuildExitNotification.self,
    // workspace
    WorkspaceDidChangeWatchedFilesNotification.self,

]

public let bspRegistry = MessageRegistry(requests: requestTypes, notifications: notificationTypes)

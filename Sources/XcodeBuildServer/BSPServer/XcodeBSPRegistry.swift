// The Swift Programming Language
// https://docs.swift.org/swift-book

fileprivate let requestTypes: [any RequestType.Type] = [
    BuildInitializeRequest.self,
    BuildShutdownRequest.self,
    TextDocumentRegisterForChangeRequest.self,
    TextDocumentSourceKitOptionsRequest.self,
    BuildTargetPrepareRequest.self,
]

fileprivate let notificationTypes: [NotificationType.Type] = [
    OnBuildInitializedNotification.self,
    OnBuildExitNotification.self,
    
]

public let bspRegistry = MessageRegistry(requests: requestTypes, notifications: notificationTypes)

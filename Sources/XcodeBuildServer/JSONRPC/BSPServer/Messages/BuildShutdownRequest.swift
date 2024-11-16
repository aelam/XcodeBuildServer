//
//  BuildShutdownRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public struct BuildShutdownRequest: RequestType {
    public let rawRequest: JSONRPCRequest
    
    public static var method: String = "build/shutdown"
    
    public init(rawRequest: JSONRPCRequest) {
        self.rawRequest = rawRequest
    }
    
    public func handle(
        _ handler: MessageHandler,
        id: RequestID
    ) async -> JSONRPCResponse? {
        fatalError()
    }
}

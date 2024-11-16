//
//  BuildInitializeRequest.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/17.
//

public final class BuildInitializeRequest: Request, @unchecked Sendable {
    public class override var method: String { "build/initialize" }
    
    override public func handle(
        _ handler: MessageHandler,
        id: RequestID
    ) async -> JSONRPCResponse {
        fatalError()
    }
}

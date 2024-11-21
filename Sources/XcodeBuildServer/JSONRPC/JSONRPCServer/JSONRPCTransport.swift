//
//  JSONRPCTransport.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

import Foundation

public enum JSONRPCTransportError: Error {
    case connectionFailed
    case disconnectionFailed
    case sendFailed
    case receiveFailed
    case listenFailed
    case acceptFailed
    case invalidMessage
}

public typealias RequestHandler = @Sendable (_ request: JSONRPCRequest, _ requestData: Data) -> Void

public protocol JSONRPCServerTransport: AnyObject, Sendable {
    func listen()
    var requestHandler: RequestHandler? { get set }
    func send(response: ResponseType) throws
}
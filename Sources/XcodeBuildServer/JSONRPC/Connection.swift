//
//  Connection.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

/// An abstract connection, allow messages to be sent to a (potentially remote) `MessageHandler`.
public protocol Connection: AnyObject, Sendable {
    /// Send a notification without a reply.
    func send(_ notification: some NotificationType)

    /// Send a request and (asynchronously) receive a reply.
    func send<Request: RequestType>(_ request: Request) async throws -> (RequestID, Request.Response)
}

/// An abstract message handler, such as a language server or client.
public protocol MessageHandler: AnyObject, Sendable {
    /// Handle a notification without a reply.
    ///
    /// The method should return as soon as the notification has been sufficiently
    /// handled to avoid out-of-order requests, e.g. once the notification has
    /// been forwarded to clangd.
    func handle(_ notification: some NotificationType)

    /// Handle a request and (asynchronously) receive a reply.
    ///
    /// The method should return as soon as the request has been sufficiently
    /// handled to avoid out-of-order requests, e.g. once the corresponding
    /// request has been sent to sourcekitd. The actual semantic computation
    /// should occur after the method returns and report the result via `reply`.
    func handle<Request: RequestType>(_ request: Request, id: RequestID) async throws -> (RequestID, Request.Response)
}

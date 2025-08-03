//
//  JSONRPCServer.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import OSLog

public final actor JSONRPCServer {
    private let transport: JSONRPCServerTransport
    private let messageRegistry: MessageRegistry
    private let messageHandler: MessageHandler
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONDecoder()

    public init(
        transport: JSONRPCServerTransport,
        messageRegistry: MessageRegistry,
        messageHandler: MessageHandler
    ) {
        self.transport = transport
        self.messageRegistry = messageRegistry
        self.messageHandler = messageHandler
    }

    public func listen() {
        transport.requestHandler = { [weak self] request, requestData in
            Task {
                await self?.onReceivedMesssage(request: request, requestData: requestData)
            }
        }
        transport.listen()
    }

    func close() async {
        logger.debug("Closing JSON-RPC server")
        transport.close()
        logger.debug("JSON-RPC server closed")
    }

    private func onReceivedMesssage(request: JSONRPCRequest, requestData: Data) async {
        logger.debug("Received method: \(request.method, privacy: .public)")

        if let requestType = messageRegistry.requestType(for: request.method) {
            await handleRequest(request: request, requestData: requestData, requestType: requestType)
        } else if let notificationType = messageRegistry.notificationType(for: request.method) {
            await handleNotification(requestData: requestData, notificationType: notificationType)
        } else {
            logger.error("Unknown method: \(request.method)")
            if let requestID = request.id {
                await sendErrorResponse(id: requestID, error: .methodNotFound("Method not found: \(request.method)"))
            }
        }
    }

    private func handleRequest(request: JSONRPCRequest, requestData: Data, requestType: any RequestType.Type) async {
        guard let requestID = request.id else {
            logger.error("Request missing ID for method: \(request.method)")
            return
        }

        do {
            let typedRequest = try jsonDecoder.decode(requestType, from: requestData)

            if let response = await typedRequest.handle(handler: messageHandler, id: requestID) {
                do {
                    try send(response: response)
                } catch {
                    logger.error("Failed to send response: \(error)")
                }
            } else {
                logger.error("Handler returned nil response for method: \(request.method)")
                await sendErrorResponse(id: requestID, error: .internalError("Handler failed to process request"))
            }
        } catch {
            logger.error("Failed to decode request for method \(request.method): \(error)")
            await sendErrorResponse(id: requestID, error: .parseError("Invalid request format"))
        }
    }

    private func handleNotification(requestData: Data, notificationType: NotificationType.Type) async {
        do {
            let typedNotification = try jsonDecoder.decode(notificationType, from: requestData)
            try await typedNotification.handle(messageHandler)
        } catch {
            logger.error("Failed to handle notification: \(error)")
            // Notifications don't have responses, so we can only log the error
        }
    }

    private func sendErrorResponse(id: RequestID, error: JSONRPCError) async {
        let errorResponse = JSONRPCErrorResponse(
            jsonrpc: "2.0",
            id: id,
            error: error
        )

        do {
            try send(response: errorResponse)
        } catch {
            logger.error("Failed to send error response: \(error)")
        }
    }

    private func send(response: ResponseType) throws {
        try transport.send(response: response)
    }
}

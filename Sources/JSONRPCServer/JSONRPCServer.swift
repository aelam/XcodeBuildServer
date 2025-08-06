//
//  JSONRPCServer.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Stream-based JSON-RPC server that processes messages using async streams
public final actor JSONRPCServer {
    private let transport: JSONRPCServerTransport
    private let messageRegistry: MessageRegistry
    private let messageHandler: MessageHandler
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    // Task handles for stream processing
    private var messageProcessingTask: Task<Void, Never>?
    private var errorProcessingTask: Task<Void, Never>?

    public init(
        transport: JSONRPCServerTransport,
        messageRegistry: MessageRegistry,
        messageHandler: MessageHandler
    ) {
        self.transport = transport
        self.messageRegistry = messageRegistry
        self.messageHandler = messageHandler
    }

    /// Start the server and begin processing messages from streams
    public func listen() async throws {
        // Start the transport
        let transportTask = Task {
            try await transport.listen()
        }

        // Start processing message stream
        messageProcessingTask = Task { [weak self] in
            guard let self else { return }

            for await message in transport.messageStream {
                await self.processMessage(message)
            }
        }

        // Start processing error stream
        errorProcessingTask = Task { [weak self] in
            guard let self else { return }

            for await error in transport.errorStream {
                await self.handleTransportError(error)
            }
        }

        // Wait for transport to complete
        try await transportTask.value
    }

    /// Close the server and cleanup resources
    public func close() async {
        // Cancel processing tasks
        messageProcessingTask?.cancel()
        errorProcessingTask?.cancel()

        // Close transport
        await transport.close()

        // Wait for tasks to complete
        _ = await messageProcessingTask?.result
        _ = await errorProcessingTask?.result

        messageProcessingTask = nil
        errorProcessingTask = nil
    }

    /// Process a single message from the message stream
    private func processMessage(_ message: JSONRPCMessage) async {
        if let requestType = messageRegistry.requestType(for: message.request.method) {
            await handleRequest(message: message, requestType: requestType)
        } else if let notificationType = messageRegistry.notificationType(for: message.request.method) {
            await handleNotification(message: message, notificationType: notificationType)
        } else {
            if let requestID = message.request.id {
                await sendErrorResponse(
                    id: requestID,
                    error: .methodNotFound("Method not found: \(message.request.method)")
                )
            }
        }
    }

    /// Handle transport errors from the error stream
    private func handleTransportError(_ error: JSONRPCTransportError) async {
        // Log transport errors but don't propagate them
        // In a real implementation, you might want to add proper logging
        print("Transport error: \(error)")
    }

    /// Handle a JSON-RPC request
    private func handleRequest(message: JSONRPCMessage, requestType: any RequestType.Type) async {
        guard let requestID = message.request.id else {
            return
        }

        do {
            let typedRequest = try jsonDecoder.decode(requestType, from: message.rawData)

            if let response = await typedRequest.handle(handler: messageHandler, id: requestID) {
                do {
                    try await send(response: response)
                } catch {
                    // Failed to send response - in a real implementation, consider retry logic
                }
            } else {
                await sendErrorResponse(
                    id: requestID,
                    error: .internalError("Handler failed to process request")
                )
            }
        } catch {
            await sendErrorResponse(id: requestID, error: .parseError("Invalid request format"))
        }
    }

    /// Handle a JSON-RPC notification
    private func handleNotification(message: JSONRPCMessage, notificationType: any NotificationType.Type) async {
        do {
            let typedNotification = try jsonDecoder.decode(notificationType, from: message.rawData)
            try await typedNotification.handle(messageHandler)
        } catch {
            // Notifications don't have responses, so we can only log the error
            print("Notification processing error: \(error)")
        }
    }

    /// Send an error response back to the client
    private func sendErrorResponse(id: RequestID, error: JSONRPCError) async {
        let errorResponse = JSONRPCErrorResponse(
            jsonrpc: "2.0",
            id: id,
            error: error
        )

        do {
            try await send(response: errorResponse)
        } catch {
            // Failed to send error response
            print("Failed to send error response: \(error)")
        }
    }

    /// Send a response using the transport
    private func send(response: ResponseType) async throws {
        try await transport.send(response: response)
    }
}

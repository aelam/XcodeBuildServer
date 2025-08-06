//
//  StdioJSONRPCServerTransport.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Stream-based stdio transport for JSON-RPC communication
public final actor StdioJSONRPCServerTransport: JSONRPCServerTransport {
    private let input: FileHandle
    private let output: FileHandle
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    // Stream continuations for async streams
    private var messageContinuation: AsyncStream<JSONRPCMessage>.Continuation?
    private var errorContinuation: AsyncStream<JSONRPCTransportError>.Continuation?

    // Streams exposed to consumers
    public let messageStream: AsyncStream<JSONRPCMessage>
    public let errorStream: AsyncStream<JSONRPCTransportError>

    // State management (actor-isolated)
    private var isListening = false

    public init() {
        input = .standardInput
        output = .standardOutput

        // Initialize message stream
        var messageCont: AsyncStream<JSONRPCMessage>.Continuation?
        messageStream = AsyncStream<JSONRPCMessage> { continuation in
            messageCont = continuation
        }
        messageContinuation = messageCont

        // Initialize error stream
        var errorCont: AsyncStream<JSONRPCTransportError>.Continuation?
        errorStream = AsyncStream<JSONRPCTransportError> { continuation in
            errorCont = continuation
        }
        errorContinuation = errorCont
    }

    public func listen() async throws {
        guard !isListening else {
            throw JSONRPCTransportError.listenFailed
        }

        isListening = true

        // Set up file handle reading
        input.readabilityHandler = { [weak self] handle in
            Task {
                await self?.handleIncomingData(from: handle)
            }
        }

        // Start waiting for data
        input.waitForDataInBackgroundAndNotify()

        // Keep the run loop running for stdio transport
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                // This continuation will be resumed when the transport is closed
                Task {
                    while self.isListening {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                    continuation.resume()
                }
            }
        } onCancel: {
            Task { await self.close() }
        }
    }

    public func close() async {
        guard isListening else { return }

        isListening = false
        input.readabilityHandler = nil

        // Close streams
        messageContinuation?.finish()
        errorContinuation?.finish()

        messageContinuation = nil
        errorContinuation = nil

        // Note: We don't close stdio handles as they are managed by the system
    }

    public func send(response: ResponseType) async throws {
        guard isListening else {
            throw JSONRPCTransportError.transportClosed
        }

        let data = try jsonEncoder.encode(response)
        let header = "Content-Length: \(data.count)\r\n\r\n"
        let headerData = header.data(using: .utf8)!

        // Debug logging
        if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
            let timestamp = DateFormatter().string(from: Date())
            let jsonString = String(data: data, encoding: .utf8) ?? "[Invalid UTF-8]"
            fputs("🔴 [\(timestamp)] OUTGOING: \(jsonString)\n", stderr)
        }

        // Perform write operations on a background queue to avoid blocking
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                self.output.write(headerData)
                self.output.write(data)
                continuation.resume()
            }
        }
    }

    private func handleIncomingData(from fileHandle: FileHandle) {
        let data = fileHandle.availableData
        guard !data.isEmpty else {
            return
        }

        do {
            let message = try parseJSONRPCMessage(from: data)
            messageContinuation?.yield(message)
        } catch {
            if let transportError = error as? JSONRPCTransportError {
                errorContinuation?.yield(transportError)
            } else {
                errorContinuation?.yield(.invalidMessage)
            }
        }

        // Continue waiting for more data
        fileHandle.waitForDataInBackgroundAndNotify()
    }

    private func parseJSONRPCMessage(from data: Data) throws -> JSONRPCMessage {
        guard let content = String(data: data, encoding: .utf8) else {
            throw JSONRPCTransportError.invalidMessage
        }

        // Parse HTTP-like headers (Content-Length: N\r\n\r\n)
        let components = content.split(separator: "\r\n", omittingEmptySubsequences: true)
        guard components.count >= 2 else {
            throw JSONRPCTransportError.invalidMessage
        }

        // Extract JSON content (skip headers)
        let jsonContent = components[1].replacing("\\/", with: "/")
        guard let rawData = jsonContent.data(using: .utf8) else {
            throw JSONRPCTransportError.invalidMessage
        }

        // Debug logging
        if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
            let timestamp = DateFormatter().string(from: Date())
            fputs("🔵 [\(timestamp)] INCOMING: \(jsonContent)\n", stderr)
        }

        // Decode JSON-RPC request
        do {
            let request = try jsonDecoder.decode(JSONRPCRequest.self, from: rawData)
            return JSONRPCMessage(request: request, rawData: rawData)
        } catch {
            throw JSONRPCTransportError.invalidMessage
        }
    }
}

//
//  StdioJSONRPCServerTransport.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

/// Stream-based stdio transport for JSON-RPC communication
public final class StdioJSONRPCServerTransport: JSONRPCServerTransport, @unchecked Sendable {
    private let input: FileHandle
    private let output: FileHandle
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    // Stream continuations for async streams
    private var messageContinuation: AsyncStream<JSONRPCMessage>.Continuation?
    private var errorContinuation: AsyncStream<JSONRPCTransportError>.Continuation?

    // Streams exposed to consumers
    public let messageStream: AsyncStream<JSONRPCMessage>
    public let errorStream: AsyncStream<JSONRPCTransportError>

    // State management (thread-safe)
    private let stateLock = NSLock()
    private var _isListening = false
    private var _closeContinuation: CheckedContinuation<Void, Never>?

    private var isListening: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isListening
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _isListening = newValue
        }
    }

    private var closeContinuation: CheckedContinuation<Void, Never>? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _closeContinuation
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _closeContinuation = newValue
        }
    }

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
            self?.handleIncomingData(from: handle)
        }

        // Start waiting for data
        input.waitForDataInBackgroundAndNotify()

        // Keep the transport running using proper async pattern
        await withTaskCancellationHandler {
            // Use a continuation that will be resumed when transport is closed
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.closeContinuation = continuation
            }
        } onCancel: {
            Task { self.close() }
        }
    }

    public func close() {
        guard isListening else { return }

        isListening = false
        input.readabilityHandler = nil

        // Close streams
        messageContinuation?.finish()
        errorContinuation?.finish()

        messageContinuation = nil
        errorContinuation = nil

        // Resume the listen continuation to exit the listen method
        closeContinuation?.resume()
        closeContinuation = nil

        // Note: We don't close stdio handles as they are managed by the system
    }

    public func send(response: ResponseType) async throws {
        guard isListening else {
            throw JSONRPCTransportError.transportClosed
        }

        let data = try jsonEncoder.encode(response)
        let header = "Content-Length:\(data.count)\r\n\r\n"
        let headerData = header.data(using: .utf8)!

        // Log sent data with pretty JSON formatting (already formatted by jsonEncoder)
        logger.debug("Sending (\(data.count) bytes):\n\(String(data: data, encoding: .utf8) ?? "[Invalid UTF-8]")")

        // Perform write operations with timeout to prevent hanging
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                throw JSONRPCTransportError.timeout
            }

            // Add write task
            group.addTask {
                // Write operations with timeout protection
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.output.write(headerData)
                        self.output.write(data)
                        // Try to flush the output
                        fsync(self.output.fileDescriptor)
                        continuation.resume()
                    }
                }
            }

            // Wait for the first task to complete and cancel the others
            try await group.next()
            group.cancelAll()
        }
    }

    private func handleIncomingData(from fileHandle: FileHandle) {
        let data = fileHandle.availableData
        guard !data.isEmpty else {
            return
        }

        // Parse the message first
        do {
            let message = try parseJSONRPCMessage(from: data)

            // Log with pretty JSON using existing encoder
            if let prettyData = try? jsonEncoder.encode(message.request),
               let prettyJson = String(data: prettyData, encoding: .utf8) {
                logger.debug("Received (\(message.rawData.count) bytes):\n\(prettyJson)")
            } else {
                let rawString = String(data: message.rawData, encoding: .utf8) ?? "[Invalid UTF-8]"
                logger.debug("Received (\(message.rawData.count) bytes):\n\(rawString)")
            }

            messageContinuation?.yield(message)
        } catch {
            // Log raw data if parsing fails
            let rawString = String(data: data, encoding: .utf8) ?? "[Invalid UTF-8]"
            logger.debug("Received invalid data (\(data.count) bytes):\n\(rawString)")

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

        // Parse HTTP-like headers (Content-Length:N\r\n\r\n)
        let components = content.split(separator: "\r\n", omittingEmptySubsequences: true)
        guard components.count >= 2 else {
            throw JSONRPCTransportError.invalidMessage
        }

        // Extract JSON content (skip headers)
        let jsonContent = components[1].replacing("\\/", with: "/")
        guard let rawData = jsonContent.data(using: .utf8) else {
            throw JSONRPCTransportError.invalidMessage
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

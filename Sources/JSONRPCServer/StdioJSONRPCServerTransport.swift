//
//  StdioJSONRPCServerTransport.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public final class StdioJSONRPCServerTransport: JSONRPCServerTransport {
    private let input: FileHandle
    private let output: FileHandle
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let requestHandlerLock = NSLock()
    private nonisolated(unsafe) var _requestHandler: RequestHandler?

    public var requestHandler: RequestHandler? {
        get {
            requestHandlerLock.lock()
            defer { requestHandlerLock.unlock() }
            return _requestHandler
        }
        set {
            requestHandlerLock.lock()
            defer { requestHandlerLock.unlock() }
            _requestHandler = newValue
        }
    }

    public init() {
        input = .standardInput
        output = .standardOutput
    }

    public func listen() {
        input.waitForDataInBackgroundAndNotify()
        input.readabilityHandler = { handle in
            try? self.handleData(fileHandle: handle)
        }

        RunLoop.current.run()
    }

    public func close() {
        input.readabilityHandler = nil
        // Note: We don't close stdio handles as they are managed by the system
    }

    private func handleData(fileHandle: FileHandle) throws {
        let data = fileHandle.availableData
        guard !data.isEmpty else {
            return
        }

        guard
            let components = String(data: data, encoding: .utf8)?.split(
                separator: "\r\n", omittingEmptySubsequences: true
            ),
            components.count >= 2
        else {
            return
        }

        let content = components[1].replacing("\\/", with: "/")
        guard let rawData = content.data(using: .utf8) else {
            return
        }

        guard let request = try? jsonDecoder.decode(JSONRPCRequest.self, from: rawData) else {
            throw JSONRPCTransportError.invalidMessage
        }
        requestHandler?(request, rawData)
    }

    public func send(response: ResponseType) throws {
        let data = try jsonEncoder.encode(response)
        let header = "Content-Length: \(data.count)\r\n\r\n"
        let headerData = header.data(using: .utf8)!
        output.write(headerData)
        output.write(data)
    }
}

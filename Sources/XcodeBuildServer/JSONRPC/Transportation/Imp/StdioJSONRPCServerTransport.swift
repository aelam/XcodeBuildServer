//
//  StdioJSONRPCTransport.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

import Foundation
import OSLog

private let privacy: OSLogPrivacy = .public
private let logger = Logger(
  subsystem: "StdioJSONRPCServerTransport",
  category: "main"
)

final public class StdioJSONRPCServerTransport: JSONRPCServerTransport {
    private let input: FileHandle
    private let output: FileHandle
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    public var requestHandler: RequestHandler?

    public init() {
        self.input = .standardInput
        self.output = .standardOutput
    }
    
    public func listen() {
        input.waitForDataInBackgroundAndNotify()
        input.readabilityHandler = { handle in
            try? self.handleData(fileHandle: handle)
        }
        
        logger.debug("==> Start XcodeBuildServer")

        RunLoop.current.run()
    }
    
    private func handleData(fileHandle: FileHandle) throws {
        let data = fileHandle.availableData
        guard
            !data.isEmpty
        else {
            return
        }

        guard
            let components = String(data: data, encoding: .utf8)?.split(
                separator: "\r\n", omittingEmptySubsequences: true),
            components.count >= 2
        else {
            return
        }
        logger.debug("components[1]: + \(components[1], privacy: .public)")
        let content = components[1].replacing("\\/", with: "/")
        guard let raw = content.data(using: .utf8) else {
            return
        }
        guard let message = String(data: raw, encoding: .utf8) else {
            throw JSONRPCTransportError.invalidMessage
        }
        
        logger.debug("Message: + \(message, privacy: .public)")
        
        guard let request = try? jsonDecoder.decode(JSONRPCRequest.self, from: raw) else {
            throw JSONRPCTransportError.invalidMessage
        }
        requestHandler?(request)
    }
    
    public func send(response: JSONRPCResponse) throws {
        let data = try jsonEncoder.encode(response)
        let header = "Content-Length: \(data.count)\r\n\r\n"
        let headerData = header.data(using: .utf8)!
        output.write(headerData)
        output.write(data)
    }
}

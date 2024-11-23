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

    func close() {}

    private func onReceivedMesssage(request: JSONRPCRequest, requestData: Data) async {
        logger.debug("Received method: \(request.method, privacy: .public)")
        if let requestType = messageRegistry.requestType(for: request.method) {
            if let requestID = request.id {
                let typedRequest = try! jsonDecoder.decode(requestType, from: requestData)
                guard let response = await typedRequest.handle(messageHandler, id: requestID) else {
                    return
                }
                try? send(response: response)
            }
        } else if let notificationType = messageRegistry.notificationType(for: request.method) {
            if let typedNotification = try? jsonDecoder.decode(notificationType, from: requestData) {
                try? await typedNotification.handle(messageHandler)
            }
        }
    }

    private func send(response: ResponseType) throws {
        try transport.send(response: response)
    }
}

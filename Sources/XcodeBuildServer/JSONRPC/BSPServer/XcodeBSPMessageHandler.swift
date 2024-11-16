//
//  DefaultMessageHandler.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

public final class XcodeBSPMessageHandler: MessageHandler {
    public init() {
        
    }
}
//    private let registry: MessageRegistry
//    private let clientTransport: JSONRPCClientTransport
//
//    public init(registry: MessageRegistry, clientTransport: JSONRPCClientTransport) {
//        self.registry = registry
//        self.clientTransport = clientTransport
//    }
//
//    public func handle(messageBody: MessageBody) async {
//        let message = try! JSONDecoder().decode(JSONRPCMessage.self, from: messageBody.data(using: .utf8)!)
//
//        if let requestType = registry.requestType(for: message.method) {
//            try! await handleRequest(requestType, message: message)
//        } else if let notificationType = registry.notificationType(for: message.method) {
//            try! await handleNotification(notificationType, message: message)
//        } else {
//            // Unknown message type
//            print("Unknown message type: \(message.method)")
//        }
//    }
//
//    private func handleRequest(_ requestType: RequestType.Type, message: JSONRPCMessage) async throws {
//        let request = try JSONDecoder().decode(requestType, from: message.params.data(using: .utf8)!)
//        let response = try await request.handle()
//        let responseMessage = JSONRPCMessage(id: message.id, result: try JSONEncoder().encode(response))
//        let responseMessageBody = try JSONEncoder().encode(responseMessage)
//        try await clientTransport.send(messageBody: String(data: responseMessageBody, encoding: .utf8)!)
//    }
//
//    private func handleNotification(_ notificationType: NotificationType.Type, message: JSONRPCMessage) async throws {
//        let notification = try JSONDecoder().decode(notificationType, from: message.params.data(using: .utf8)!)
//        try await notification.handle()
//    }
//}

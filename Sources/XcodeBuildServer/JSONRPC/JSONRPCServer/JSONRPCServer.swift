import Foundation
import OSLog

private let privacy: OSLogPrivacy = .public
private let logger = Logger(
  subsystem: "XocdeBuildServer.JSONRPCServer",
  category: "main"
)

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
        transport.requestHandler = onReceivedMesssage
        transport.listen()
    }

    func close() {
    }
    
    private func onReceivedMesssage(request: JSONRPCRequest) {
        logger.debug("Received request: \(request.method, privacy: .public)")
        if let requestType = messageRegistry.requestType(for: request.method) {
            if let typedRequest = requestType.init(rawRequest: request), let requestID = request.id {
                logger.debug("Received request: \(type(of: typedRequest), privacy: .public)")
                Task {
                    guard let response = try await typedRequest.handle(messageHandler, id: requestID) else { return }
                    try? send(JSONRPCResponse: response)
                }
            }
        } else if let notificationType = messageRegistry.notificationType(for: request.method) {
            logger.debug("Received notification: \(request.method, privacy: .public)")
            if let typedNotification = notificationType.init(rawRequest: request) {
                Task {
                    try await typedNotification.handle(messageHandler)
                }
            }
        }
    }
    
    private func send(JSONRPCResponse response: JSONRPCResponse) throws {
        try transport.send(response: response)
    }
}

import Foundation

enum ConnectionType {
    case stdio(inputStream: InputStream, output: OutputStream)
}

public final class JSONRPCConnection: Connection {
    private let idCounter: Int
    private let connectionType: ConnectionType
    private let messageRegistry: MessageRegistry
    private let messageHandler: MessageHandler

    init(
        connectionType: ConnectionType,
        messageRegistry: MessageRegistry,
        messageHandler: MessageHandler
    ) {
        self.connectionType = connectionType
        idCounter = 0
        self.messageRegistry = messageRegistry
        self.messageHandler = messageHandler
        setupConnection()
    }

    private func setupConnection() {
        switch connectionType {
        case let .stdio(inputStream, outputStream):
            inputStream.open()
            outputStream.open()
        }
    }

    func close() {
        switch connectionType {
        case let .stdio(inputStream, outputStream):
            inputStream.close()
            outputStream.close()
        }
    }

    public func send(_: some NotificationType) {}

    public func send<Request>(_: Request) throws -> (RequestID, Request.Response) where Request: RequestType {
        throw NSError()
    }
}

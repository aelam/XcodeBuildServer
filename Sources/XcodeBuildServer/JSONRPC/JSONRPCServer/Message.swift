//

public typealias RequestID = JSONRPCID

public protocol MessageType: Codable, Sendable {}

public protocol RequestType: Codable, Sendable {
    static var method: String { get }
    var rawRequest: JSONRPCRequest { get }
    
    init?(rawRequest: JSONRPCRequest)
    
    func handle(
        _ handler: MessageHandler,
        id: RequestID
    ) async -> JSONRPCResponse?
}

open class Request: RequestType, @unchecked Sendable {
    public class var method: String { fatalError("implement in the RequestType: \(self)") }
    public let rawRequest: JSONRPCRequest
    
    public required init?(rawRequest: JSONRPCRequest) {
        self.rawRequest = rawRequest
    }
    
    public func handle(
        _ handler: MessageHandler,
        id: RequestID
    ) async -> JSONRPCResponse? {
        fatalError("implement in the RequestType: \(self)")
    }
}

public protocol ResponseType: MessageType {}

/// A notification, which must have a unique `method` name.
public protocol NotificationType: MessageType {
    /// The name of the request.
    static var method: String { get }
    
    var rawRequest: JSONRPCRequest { get }
    init?(rawRequest: JSONRPCRequest)

    func handle(_ handler: MessageHandler) async throws
}

open class Notification: NotificationType, @unchecked Sendable {
    public class var method: String { fatalError("implement in the RequestType: \(self)") }
    public let rawRequest: JSONRPCRequest
    
    public required init?(rawRequest: JSONRPCRequest) {
        self.rawRequest = rawRequest
    }

    public func handle(
        _ handler: MessageHandler
    ) async {
        fatalError("implement in the RequestType: \(self)")
    }
}

public struct VoidResponse: ResponseType, Hashable {
    public init() {}
}

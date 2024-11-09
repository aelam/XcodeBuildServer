//

public protocol MessageType: Codable, Sendable {}

public protocol RequestType: Codable, Sendable {
    associatedtype Response: ResponseType
    static var method: String { get }

    func handle(_ handler: MessageHandler, id: RequestID) async throws -> (RequestID, ResponseType)
}

public protocol ResponseType: MessageType {}

/// A notification, which must have a unique `method` name.
public protocol NotificationType: MessageType {
    /// The name of the request.
    static var method: String { get }
}

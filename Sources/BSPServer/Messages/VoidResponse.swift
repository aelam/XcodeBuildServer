import JSONRPCConnection

public struct VoidParams: Codable, Sendable {
    // Empty struct for void parameters
}

public struct VoidResponse: ResponseType, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCID?
    public let result: VoidResult?

    public init(jsonrpc: String, id: JSONRPCID?) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = VoidResult()
    }
}

public struct VoidResult: Codable, Sendable {
    // Empty struct for void responses

    public init() {}
}

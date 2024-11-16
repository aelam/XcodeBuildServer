//
//  JSONRPCMessage.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/09.
//

import Foundation

public enum JSONRPCID: Codable, Equatable, Hashable, Sendable {
    case int(Int)
    case string(String)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let intValue):
            try container.encode(intValue)
        case .string(let stringValue):
            try container.encode(stringValue)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(JSONRPCID.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "ID is not a valid type"))
        }
    }
}

public struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String
    let id: JSONRPCID?
    let method: String
    let params: JSONValue?
}

public struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: JSONValue?
}

public enum JSONRPCResult: Codable {
    case result(JSONValue)
    case error(JSONRPCError)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let result = try? container.decode(JSONValue.self, forKey: .result) {
            self = .result(result)
        } else if let error = try? container.decode(JSONRPCError.self, forKey: .error) {
            self = .error(error)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .result, in: container, debugDescription: "Response must have either result or error")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .result(let result):
            try container.encode(result, forKey: .result)
        case .error(let error):
            try container.encode(error, forKey: .error)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case result
        case error
    }
}

public struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: JSONRPCID?
    let response: JSONRPCResult
}

public enum JSONValue: Codable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case array([JSONValue])
    case dictionary([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else if let dictionaryValue = try? container.decode([String: JSONValue].self) {
            self = .dictionary(dictionaryValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .int(let intValue):
            try container.encode(intValue)
        case .double(let doubleValue):
            try container.encode(doubleValue)
        case .string(let stringValue):
            try container.encode(stringValue)
        case .bool(let boolValue):
            try container.encode(boolValue)
        case .array(let arrayValue):
            try container.encode(arrayValue)
        case .dictionary(let dictionaryValue):
            try container.encode(dictionaryValue)
        case .null:
            try container.encodeNil()
        }
    }
}

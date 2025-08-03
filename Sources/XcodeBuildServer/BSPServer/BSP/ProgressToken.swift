//
//  ProgressToken.swift
//  XcodeBuildServer
//
//  Created by ST22956 on 2024/11/23.
//

public enum ProgressToken: Codable, Hashable, Sendable {
    case integer(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        if let integer = try? Int(from: decoder) {
            self = .integer(integer)
        } else if let string = try? String(from: decoder) {
            self = .string(string)
        } else {
            let context = DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected Int or String"
            )
            throw DecodingError.dataCorrupted(context)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .integer(let integer):
            try integer.encode(to: encoder)
        case .string(let string):
            try string.encode(to: encoder)
        }
    }
}

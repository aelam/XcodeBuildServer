/// Represents a build setting value that can be a string or array of strings
public enum BuildSettingValue: Codable {
    case string(String)
    case array([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(
                BuildSettingValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .array(values):
            try container.encode(values)
        }
    }

    /// Convert to string representation
    public var stringValue: String {
        switch self {
        case let .string(value):
            value
        case let .array(values):
            values.joined(separator: " ")
        }
    }
}

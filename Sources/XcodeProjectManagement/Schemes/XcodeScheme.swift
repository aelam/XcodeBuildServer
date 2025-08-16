import Foundation

public struct XcodeScheme: Sendable, Codable {
    public let name: String
    public let path: URL
    public let container: String // "workspace" or project name
}

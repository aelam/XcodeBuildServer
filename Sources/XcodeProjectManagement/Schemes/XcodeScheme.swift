import Foundation

public struct XcodeScheme: Sendable {
    let name: String
    let path: URL
    let container: String // "workspace" or project name
}

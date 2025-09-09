import Foundation

public extension String {
    var expandingTildeInPath: String {
        (self as NSString).expandingTildeInPath
    }

    var absolutePath: String {
        var path = self

        if path.hasPrefix("~") {
            if let home = ProcessInfo.processInfo.environment["HOME"] {
                let start = path.index(after: path.startIndex)
                path = home + path[start...]
            }
        }

        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    var isRelativePath: Bool {
        if self.isEmpty { return true }
        if self.hasPrefix("/") { return false }
        if self.hasPrefix("~") { return true }
        return true
    }
}

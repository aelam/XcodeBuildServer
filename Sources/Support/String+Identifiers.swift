import CryptoKit
import Foundation

public extension String {
    /// 转换为合法的 C99 扩展标识符
    /// - 保留 [A-Za-z0-9_]
    /// - 其它字符替换成 `_`
    /// - 首字符必须是字母或 `_`
    func asC99ExtIdentifier() -> String {
        var result = ""
        result.reserveCapacity(self.count)

        for ch in self {
            if ch.isLetter || ch.isNumber || ch == "_" {
                result.append(ch)
            } else {
                result.append("_")
            }
        }

        // 确保首字符是字母或 `_`
        if let first = result.first, !(first.isLetter || first == "_") {
            result = "_" + result.dropFirst()
        }

        return result
    }

    /// 转换为符合 RFC1034 的标识符（常用于 bundle identifier）
    /// - 保留 [A-Za-z0-9-]
    /// - 其它字符替换成 `-`
    func asRFC1034Identifier() -> String {
        var result = ""
        result.reserveCapacity(self.count)

        for ch in self {
            if ch.isLetter || ch.isNumber || ch == "-" {
                result.append(ch)
            } else {
                result.append("-")
            }
        }

        return result
    }

    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

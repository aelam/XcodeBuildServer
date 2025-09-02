import Foundation

actor JSONPRCParser {
    typealias Result = Swift.Result<JSONRPCMessage, JSONRPCTransportError>

    private let jsonDecoder = JSONDecoder()
    private let separator = "\r\n\r\n"
    private var buffer = Data()

    nonisolated(unsafe) var handler: ((Result) -> Void)?

    func feed(chunk: Data) {
        buffer.append(chunk)

        while true {
            // 找到 header/body 分隔符
            guard let range = buffer.range(of: separator.data(using: .utf8)!) else {
                break // header 不完整
            }

            let headerData = buffer.subdata(in: 0 ..< range.lowerBound)
            guard let headerString = String(data: headerData, encoding: .utf8) else {
                handler?(.failure(JSONRPCTransportError.invalidHeader))
                return
            }

            // 提取 Content-Length
            guard let lengthLine = headerString
                .split(separator: separator)
                .first(where: { $0.lowercased().hasPrefix("content-length") }),
                let lengthValue = lengthLine.split(separator: ":").last,
                let contentLength = Int(lengthValue.trimmingCharacters(in: .whitespaces)) else {
                handler?(.failure(JSONRPCTransportError.missingContentLength))
                return
            }

            let headerEnd = range.upperBound
            let totalLength = headerEnd + contentLength

            // body 不完整
            guard buffer.count >= totalLength else {
                break
            }

            // 提取 body
            let bodyData = buffer.subdata(in: headerEnd ..< totalLength)

            do {
                let message = try jsonDecoder.decode(JSONRPCRequest.self, from: bodyData)
                handler?(.success(JSONRPCMessage(request: message, rawData: bodyData)))
            } catch {
                handler?(.failure(.invalidHeader))
            }

            buffer.removeSubrange(0 ..< totalLength)
        }
    }
}

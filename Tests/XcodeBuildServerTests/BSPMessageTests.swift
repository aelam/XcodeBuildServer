@testable import XcodeBuildServer
import XCTest

final class BSPMessageTests: XCTestCase {
    func testExample() throws {
        let message = """
Content-Length: 100\r\n\
{
  "jsonrpc": "2.0",
  "method": "exampleMethod",
  "params": {
    "key": "value"
  },
  "id": 1
}

"""

        let message = JSONRPCMessage(
            id: 1,
            method: "build/shutdown",
            params: nil
        )
        /*

         */
    }
}

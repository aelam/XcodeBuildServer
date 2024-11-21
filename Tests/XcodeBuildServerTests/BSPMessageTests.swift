//
//  BSPMessageTests.swift
//
//  Copyright © 2024 Wang Lun.
//

@testable import XcodeBuildServer
import XCTest

final class BSPMessageTests: XCTestCase {
    func testBuildInitialize() throws {
        let message = """
        {
          "jsonrpc": "2.0",
          "method": "build/initialize",
          "capabilities": {
            "languageIds": [
              "c",
              "cpp",
              "objective-c",
              "objective-cpp",
              "swift"
            ]
          },
          "id": 1
        }
        """

        let data = message.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        if let requestType: RequestType.Type = bspRegistry.requestType(for: request.method) {
            let typedRequest = try JSONDecoder().decode(requestType.self, from: data)
            print(typedRequest)
        }

        XCTAssertEqual(request.method, "build/initialize")
    }
}

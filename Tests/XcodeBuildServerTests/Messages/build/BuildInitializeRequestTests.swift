//
//  BuildInitializeRequestTests.swift
//  XcodeBuildServer
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeBuildServer

struct BuildInitializeRequestTests {
    @Test
    func jsonDecoding() throws {
        let jsonData = Data("""
        {
            "id": 1,
            "jsonrpc": "2.0",
            "method": "build/initialize",
            "params": {
                "rootUri": "file:///Users/test/project",
                "capabilities": {
                    "languageIds": ["swift", "objective-c", "c", "cpp"]
                },
                "displayName": "Test Client"
            }
        }
        """.utf8)

        let request = try JSONDecoder().decode(BuildInitializeRequest.self, from: jsonData)

        #expect(request.id == .int(1))
        #expect(request.params.rootUri == "file:///Users/test/project")
        #expect(request.params.displayName == "Test Client")
        #expect(request.params.capabilities.languageIds.count == 4)
        #expect(request.params.capabilities.languageIds.contains(.swift))
        #expect(request.params.capabilities.languageIds.contains(.objective_c))
        #expect(request.params.capabilities.languageIds.contains(.c))
        #expect(request.params.capabilities.languageIds.contains(.cpp))
    }

    @Test
    func jsonDecodingWithOptionalDisplayName() throws {
        let jsonData = Data("""
        {
            "id": "test-id",
            "jsonrpc": "2.0",
            "method": "build/initialize",
            "params": {
                "rootUri": "file:///Users/test/project",
                "capabilities": {
                    "languageIds": ["swift"]
                }
            }
        }
        """.utf8)

        let request = try JSONDecoder().decode(BuildInitializeRequest.self, from: jsonData)

        #expect(request.id == .string("test-id"))
        #expect(request.params.rootUri == "file:///Users/test/project")
        #expect(request.params.displayName == nil)
        #expect(request.params.capabilities.languageIds.count == 1)
        #expect(request.params.capabilities.languageIds.first == .swift)
    }

    @Test
    func method() {
        #expect(BuildInitializeRequest.method() == "build/initialize")
    }

    @Test
    func jsonEncoding() throws {
        let capabilities = BuildInitializeRequest.Params.BuildClientCapabilities(
            languageIds: [.swift, .c]
        )
        let params = BuildInitializeRequest.Params(
            rootUri: "file:///Users/test/project",
            capabilities: capabilities,
            displayName: "Test Client"
        )
        let request = BuildInitializeRequest(
            id: .int(42),
            params: params
        )

        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(BuildInitializeRequest.self, from: encoded)

        #expect(decoded.id == .int(42))
        #expect(decoded.params.rootUri == "file:///Users/test/project")
        #expect(decoded.params.displayName == "Test Client")
        #expect(decoded.params.capabilities.languageIds.count == 2)
        #expect(decoded.params.capabilities.languageIds.contains(.swift))
        #expect(decoded.params.capabilities.languageIds.contains(.c))
    }

    @Test
    func invalidJSON() {
        let invalidJsonData = Data("""
        {
            "id": 1,
            "jsonrpc": "2.0",
            "method": "build/initialize"
        }
        """.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(BuildInitializeRequest.self, from: invalidJsonData)
        }
    }

    @Test
    func emptyLanguageIds() throws {
        let jsonData = Data("""
        {
            "id": 1,
            "jsonrpc": "2.0",
            "method": "build/initialize",
            "params": {
                "rootUri": "file:///Users/test/project",
                "capabilities": {
                    "languageIds": []
                },
                "displayName": "Test Client"
            }
        }
        """.utf8)

        let request = try JSONDecoder().decode(BuildInitializeRequest.self, from: jsonData)

        #expect(request.params.capabilities.languageIds.isEmpty)
    }

    @Test
    func complexRootUri() throws {
        let complexUri = "file:///Users/test/project%20with%20spaces"
        let jsonData = Data("""
        {
            "id": 1,
            "jsonrpc": "2.0",
            "method": "build/initialize",
            "params": {
                "rootUri": "\(complexUri)",
                "capabilities": {
                    "languageIds": ["swift"]
                },
                "displayName": "Test Client"
            }
        }
        """.utf8)

        let request = try JSONDecoder().decode(BuildInitializeRequest.self, from: jsonData)

        #expect(request.params.rootUri == complexUri)
    }
}

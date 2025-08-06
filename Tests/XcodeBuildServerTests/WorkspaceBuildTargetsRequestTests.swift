//
//  WorkspaceBuildTargetsRequestTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeBuildServer

struct WorkspaceBuildTargetsRequestTests {
    @Test
    func testMethod() {
        #expect(WorkspaceBuildTargetsRequest.method() == "workspace/buildTargets")
    }

    @Test
    func paramsInit() {
        let params1 = WorkspaceBuildTargetsRequest.Params()
        #expect(params1.targets == [])

        let params2 = WorkspaceBuildTargetsRequest.Params(targets: ["target1", "target2"])
        #expect(params2.targets == ["target1", "target2"])
    }

    @Test
    func paramsCodable() throws {
        let params = WorkspaceBuildTargetsRequest.Params(targets: ["MyApp", "MyFramework"])

        let encoder = JSONEncoder()
        let data = try encoder.encode(params)

        let decoder = JSONDecoder()
        let decodedParams = try decoder.decode(WorkspaceBuildTargetsRequest.Params.self, from: data)

        #expect(decodedParams.targets == ["MyApp", "MyFramework"])
    }

    @Test
    func requestStructure() {
        let request = WorkspaceBuildTargetsRequest(
            id: .string("test-id"),
            jsonrpc: "2.0",
            params: WorkspaceBuildTargetsRequest.Params(targets: ["TestTarget"])
        )

        #expect(request.jsonrpc == "2.0")
        #expect(request.params?.targets == ["TestTarget"])

        switch request.id {
        case let .string(value):
            #expect(value == "test-id")
        default:
            Issue.record("Expected string ID")
        }
    }

    @Test
    func requestWithNilParams() {
        let request = WorkspaceBuildTargetsRequest(
            id: .int(123),
            jsonrpc: "2.0",
            params: nil
        )

        #expect(request.jsonrpc == "2.0")
        #expect(request.params == nil)

        switch request.id {
        case let .int(value):
            #expect(value == 123)
        default:
            Issue.record("Expected int ID")
        }
    }
}

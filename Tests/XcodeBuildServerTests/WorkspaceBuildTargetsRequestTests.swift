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
    func requestStructure() {
        let request = WorkspaceBuildTargetsRequest(
            id: .string("test-id"),
            jsonrpc: "2.0",
            params: WorkspaceBuildTargetsRequest.Params()
        )

        #expect(request.jsonrpc == "2.0")

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

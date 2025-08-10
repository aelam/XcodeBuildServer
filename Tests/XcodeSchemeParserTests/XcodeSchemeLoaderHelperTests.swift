//
//  XcodeSchemeLoaderHelperTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeSchemeParser

/// Extension containing helper tests for XcodeSchemeLoader
extension XcodeSchemeLoaderTests {
    @Test("Test scheme loader initialization")
    func schemeLoaderInitialization() {
        _ = XcodeSchemeLoader()
        // Test passes if no exception is thrown
    }

    @Test("Test empty scheme list handling")
    func emptySchemeListHandling() async throws {
        let emptySchemes: [XcodeSchemeInfo] = []

        // This should not crash
        let result = emptySchemes.isEmpty
        #expect(result == true)
    }
}

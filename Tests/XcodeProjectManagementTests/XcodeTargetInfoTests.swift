//
//  XcodeTargetInfoTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeTargetInfoTests {
    @Test
    func xcodeProductTypeProperty() {
        let targetInfo = XcodeTargetInfo(
            name: "MyApp",
            productType: "com.apple.product-type.application",
            buildSettings: [:]
        )

        #expect(targetInfo.xcodeProductType == .application)
    }

    @Test
    func xcodeProductTypePropertyWithNil() {
        let targetInfo = XcodeTargetInfo(
            name: "MyApp",
            productType: nil,
            buildSettings: [:]
        )

        #expect(targetInfo.xcodeProductType == nil)
    }

    @Test
    func xcodeProductTypePropertyWithUnknown() {
        let targetInfo = XcodeTargetInfo(
            name: "MyApp",
            productType: "com.apple.product-type.unknown",
            buildSettings: [:]
        )

        #expect(targetInfo.xcodeProductType == nil)
    }

    @Test
    func isTestTargetWithProductType() {
        let unitTestTarget = XcodeTargetInfo(
            name: "MyAppTests",
            productType: "com.apple.product-type.bundle.unit-test",
            buildSettings: [:]
        )

        let uiTestTarget = XcodeTargetInfo(
            name: "MyAppUITests",
            productType: "com.apple.product-type.bundle.ui-testing",
            buildSettings: [:]
        )

        let appTarget = XcodeTargetInfo(
            name: "MyApp",
            productType: "com.apple.product-type.application",
            buildSettings: [:]
        )

        #expect(unitTestTarget.isTestTarget)
        #expect(uiTestTarget.isTestTarget)
        #expect(!appTarget.isTestTarget)
    }

    @Test
    func isTestTargetWithNameFallback() {
        let testTarget = XcodeTargetInfo(
            name: "MyAppTests",
            productType: nil,
            buildSettings: [:]
        )

        let regularTarget = XcodeTargetInfo(
            name: "MyApp",
            productType: nil,
            buildSettings: [:]
        )

        // Name-based fallback is still supported when productType is nil
        #expect(testTarget.isTestTarget)
        #expect(!regularTarget.isTestTarget)
    }

    @Test
    func testIsUITestTarget() {
        let uiTestTarget = XcodeTargetInfo(
            name: "MyAppUITests",
            productType: "com.apple.product-type.bundle.ui-testing",
            buildSettings: [:]
        )

        let unitTestTarget = XcodeTargetInfo(
            name: "MyAppTests",
            productType: "com.apple.product-type.bundle.unit-test",
            buildSettings: [:]
        )

        #expect(uiTestTarget.isUITestTarget)
        #expect(!unitTestTarget.isUITestTarget)
    }

    @Test
    func testIsRunnableTarget() {
        let appTarget = XcodeTargetInfo(
            name: "MyApp",
            productType: "com.apple.product-type.application",
            buildSettings: [:]
        )

        let extensionTarget = XcodeTargetInfo(
            name: "MyExtension",
            productType: "com.apple.product-type.app-extension",
            buildSettings: [:]
        )

        let frameworkTarget = XcodeTargetInfo(
            name: "MyFramework",
            productType: "com.apple.product-type.framework",
            buildSettings: [:]
        )

        #expect(appTarget.isRunnableTarget)
        #expect(extensionTarget.isRunnableTarget)
        #expect(!frameworkTarget.isRunnableTarget)
    }

    @Test
    func testIsApplicationTarget() {
        let appTarget = XcodeTargetInfo(
            name: "MyApp",
            productType: "com.apple.product-type.application",
            buildSettings: [:]
        )

        let watchAppTarget = XcodeTargetInfo(
            name: "MyWatchApp",
            productType: "com.apple.product-type.application.watchapp",
            buildSettings: [:]
        )

        let frameworkTarget = XcodeTargetInfo(
            name: "MyFramework",
            productType: "com.apple.product-type.framework",
            buildSettings: [:]
        )

        #expect(appTarget.isApplicationTarget)
        #expect(watchAppTarget.isApplicationTarget)
        #expect(!frameworkTarget.isApplicationTarget)
    }

    @Test
    func testIsLibraryTarget() {
        let frameworkTarget = XcodeTargetInfo(
            name: "MyFramework",
            productType: "com.apple.product-type.framework",
            buildSettings: [:]
        )

        let staticLibTarget = XcodeTargetInfo(
            name: "MyStaticLib",
            productType: "com.apple.product-type.library.static",
            buildSettings: [:]
        )

        let dynamicLibTarget = XcodeTargetInfo(
            name: "MyDynamicLib",
            productType: "com.apple.product-type.library.dynamic",
            buildSettings: [:]
        )

        let appTarget = XcodeTargetInfo(
            name: "MyApp",
            productType: "com.apple.product-type.application",
            buildSettings: [:]
        )

        #expect(frameworkTarget.isLibraryTarget)
        #expect(staticLibTarget.isLibraryTarget)
        #expect(dynamicLibTarget.isLibraryTarget)
        #expect(!appTarget.isLibraryTarget)
    }
}

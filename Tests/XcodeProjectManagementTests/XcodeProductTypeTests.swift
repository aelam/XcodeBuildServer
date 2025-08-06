//
//  XcodeProductTypeTests.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Testing
@testable import XcodeProjectManagement

struct XcodeProductTypeTests {
    @Test
    func productTypeRawValues() {
        #expect(XcodeProductType.application.rawValue == "com.apple.product-type.application")
        #expect(XcodeProductType.framework.rawValue == "com.apple.product-type.framework")
        #expect(XcodeProductType.staticLibrary.rawValue == "com.apple.product-type.library.static")
        #expect(XcodeProductType.dynamicLibrary.rawValue == "com.apple.product-type.library.dynamic")
        #expect(XcodeProductType.unitTest.rawValue == "com.apple.product-type.bundle.unit-test")
        #expect(XcodeProductType.uiTest.rawValue == "com.apple.product-type.bundle.ui-testing")
        #expect(XcodeProductType.appExtension.rawValue == "com.apple.product-type.app-extension")
        #expect(XcodeProductType.watchApp.rawValue == "com.apple.product-type.application.watchapp")
        #expect(XcodeProductType.watchExtension.rawValue == "com.apple.product-type.watchkit-extension")
        #expect(XcodeProductType.bundle.rawValue == "com.apple.product-type.bundle")
        #expect(XcodeProductType.tool.rawValue == "com.apple.product-type.tool")
    }

    @Test
    func initFromRawValue() {
        #expect(XcodeProductType(rawValue: "com.apple.product-type.application") == .application)
        #expect(XcodeProductType(rawValue: "com.apple.product-type.framework") == .framework)
        #expect(XcodeProductType(rawValue: "com.apple.product-type.bundle.unit-test") == .unitTest)
        #expect(XcodeProductType(rawValue: "com.apple.product-type.bundle.ui-testing") == .uiTest)
        #expect(XcodeProductType(rawValue: "com.apple.product-type.unknown") == nil)
    }

    @Test
    func testIsTestType() {
        #expect(XcodeProductType.unitTest.isTestType)
        #expect(XcodeProductType.uiTest.isTestType)

        #expect(!XcodeProductType.application.isTestType)
        #expect(!XcodeProductType.framework.isTestType)
        #expect(!XcodeProductType.staticLibrary.isTestType)
        #expect(!XcodeProductType.dynamicLibrary.isTestType)
        #expect(!XcodeProductType.appExtension.isTestType)
        #expect(!XcodeProductType.watchApp.isTestType)
        #expect(!XcodeProductType.watchExtension.isTestType)
        #expect(!XcodeProductType.bundle.isTestType)
        #expect(!XcodeProductType.tool.isTestType)
    }

    @Test
    func testIsLibraryType() {
        #expect(XcodeProductType.framework.isLibraryType)
        #expect(XcodeProductType.staticLibrary.isLibraryType)
        #expect(XcodeProductType.dynamicLibrary.isLibraryType)

        #expect(!XcodeProductType.application.isLibraryType)
        #expect(!XcodeProductType.unitTest.isLibraryType)
        #expect(!XcodeProductType.uiTest.isLibraryType)
        #expect(!XcodeProductType.appExtension.isLibraryType)
        #expect(!XcodeProductType.watchApp.isLibraryType)
        #expect(!XcodeProductType.watchExtension.isLibraryType)
        #expect(!XcodeProductType.bundle.isLibraryType)
        #expect(!XcodeProductType.tool.isLibraryType)
    }

    @Test
    func testIsApplicationType() {
        #expect(XcodeProductType.application.isApplicationType)
        #expect(XcodeProductType.watchApp.isApplicationType)

        #expect(!XcodeProductType.framework.isApplicationType)
        #expect(!XcodeProductType.staticLibrary.isApplicationType)
        #expect(!XcodeProductType.dynamicLibrary.isApplicationType)
        #expect(!XcodeProductType.unitTest.isApplicationType)
        #expect(!XcodeProductType.uiTest.isApplicationType)
        #expect(!XcodeProductType.appExtension.isApplicationType)
        #expect(!XcodeProductType.watchExtension.isApplicationType)
        #expect(!XcodeProductType.bundle.isApplicationType)
        #expect(!XcodeProductType.tool.isApplicationType)
    }

    @Test
    func testIsRunnableType() {
        #expect(XcodeProductType.application.isRunnableType)
        #expect(XcodeProductType.watchApp.isRunnableType)
        #expect(XcodeProductType.appExtension.isRunnableType)

        #expect(!XcodeProductType.framework.isRunnableType)
        #expect(!XcodeProductType.staticLibrary.isRunnableType)
        #expect(!XcodeProductType.dynamicLibrary.isRunnableType)
        #expect(!XcodeProductType.unitTest.isRunnableType)
        #expect(!XcodeProductType.uiTest.isRunnableType)
        #expect(!XcodeProductType.watchExtension.isRunnableType)
        #expect(!XcodeProductType.bundle.isRunnableType)
        #expect(!XcodeProductType.tool.isRunnableType)
    }

    @Test
    func caseIterable() {
        let allCases = XcodeProductType.allCases
        #expect(allCases.count == 11)
        #expect(allCases.contains(.application))
        #expect(allCases.contains(.framework))
        #expect(allCases.contains(.staticLibrary))
        #expect(allCases.contains(.dynamicLibrary))
        #expect(allCases.contains(.unitTest))
        #expect(allCases.contains(.uiTest))
        #expect(allCases.contains(.appExtension))
        #expect(allCases.contains(.watchApp))
        #expect(allCases.contains(.watchExtension))
        #expect(allCases.contains(.bundle))
        #expect(allCases.contains(.tool))
    }
}

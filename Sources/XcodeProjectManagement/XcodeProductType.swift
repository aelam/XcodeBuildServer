//
//  XcodeProductType.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public enum XcodeProductType: String, CaseIterable, Sendable {
    case application = "com.apple.product-type.application"
    case framework = "com.apple.product-type.framework"
    case staticLibrary = "com.apple.product-type.library.static"
    case dynamicLibrary = "com.apple.product-type.library.dynamic"
    case unitTest = "com.apple.product-type.bundle.unit-test"
    case uiTest = "com.apple.product-type.bundle.ui-testing"
    case appExtension = "com.apple.product-type.app-extension"
    case watchApp = "com.apple.product-type.application.watchapp"
    case watchExtension = "com.apple.product-type.watchkit-extension"
    case bundle = "com.apple.product-type.bundle"
    case tool = "com.apple.product-type.tool"

    public var isTestType: Bool {
        self == .unitTest || self == .uiTest
    }

    public var isLibraryType: Bool {
        self == .framework || self == .staticLibrary || self == .dynamicLibrary
    }

    public var isApplicationType: Bool {
        self == .application || self == .watchApp
    }

    public var isRunnableType: Bool {
        isApplicationType || self == .appExtension
    }
}

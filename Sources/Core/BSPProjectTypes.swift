//
//  BSPProjectTypes.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// 项目类型枚举
public enum BSPProjectType: String, Codable, CaseIterable, Sendable {
    case xcode
    case swiftpm
    case unknown
}

public enum ProductType: String, Codable, CaseIterable, Sendable {
    case application
    case framework
    case staticLibrary = "static_library"
    case dynamicLibrary = "dynamic_library"
    case unitTestBundle = "unit_test_bundle"
    case uiTestBundle = "ui_test_bundle"
    case unknown
}

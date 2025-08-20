//
//  ProjectTypes.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public enum ProductType: String, Codable, CaseIterable, Sendable {
    case application
    case framework
    case staticLibrary = "static_library"
    case dynamicLibrary = "dynamic_library"
    case unitTestBundle = "unit_test_bundle"
    case uiTestBundle = "ui_test_bundle"
    case unknown
}

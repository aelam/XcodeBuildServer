//
//  ProjectTypes.swift
//  Core Module
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public enum ProductType: CaseIterable, Sendable {
    case none
    case application
    case framework
    case staticFramework
    case xcFramework
    case dynamicLibrary
    case staticLibrary
    case bundle
    case unitTestBundle
    case uiTestBundle
    case appExtension
    case extensionKitExtension
    case commandLineTool
    case watchApp
    case watch2App
    case watch2AppContainer
    case watchExtension
    case watch2Extension
    case tvExtension
    case messagesApplication
    case messagesExtension
    case stickerPack
    case xpcService
    case ocUnitTestBundle
    case xcodeExtension
    case instrumentsPackage
    case intentsServiceExtension
    case onDemandInstallCapableApplication
    case metalLibrary
    case driverExtension
    case systemExtension
}

public extension ProductType {
    var isTestType: Bool {
        switch self {
        case .unitTestBundle, .uiTestBundle, .ocUnitTestBundle:
            true
        default:
            false
        }
    }

    var isLibraryType: Bool {
        switch self {
        case .framework, .staticLibrary, .dynamicLibrary, .staticFramework:
            true
        default:
            false
        }
    }

    var isApplicationType: Bool {
        switch self {
        case .application, .watchApp, .watch2App:
            true
        default:
            false
        }
    }

    var isRunnableType: Bool {
        switch self {
        case .application, .watchApp, .watch2App, .watchExtension, .watch2Extension, .commandLineTool, .appExtension:
            true
        default:
            false
        }
    }
}

//
//  XcodeProductType+Product.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import BSPTypes
import XcodeProjectManagement

public extension XcodeProductType {
    var asProductType: ProductType {
        switch self {
        case .none:
            .none
        case .application:
            .application
        case .framework:
            .framework
        case .staticFramework:
            .staticLibrary
        case .xcFramework:
            .framework
        case .dynamicLibrary:
            .dynamicLibrary
        case .staticLibrary:
            .staticLibrary
        case .bundle:
            .bundle
        case .unitTestBundle:
            .unitTestBundle
        case .uiTestBundle:
            .uiTestBundle
        case .appExtension:
            .appExtension
        case .extensionKitExtension:
            .extensionKitExtension
        case .commandLineTool:
            .commandLineTool
        case .watchApp:
            .watchApp
        case .watch2App:
            .watch2App
        case .watch2AppContainer:
            .watch2AppContainer
        case .watchExtension:
            .watchExtension
        case .watch2Extension:
            .watch2Extension
        case .tvExtension:
            .tvExtension
        case .messagesApplication:
            .messagesApplication
        case .messagesExtension:
            .messagesExtension
        case .stickerPack:
            .stickerPack
        case .xpcService:
            .xpcService
        case .ocUnitTestBundle:
            .ocUnitTestBundle
        case .xcodeExtension:
            .xcodeExtension
        case .instrumentsPackage:
            .instrumentsPackage
        case .intentsServiceExtension:
            .intentsServiceExtension
        case .onDemandInstallCapableApplication:
            .onDemandInstallCapableApplication
        case .metalLibrary:
            .metalLibrary
        case .driverExtension:
            .driverExtension
        case .systemExtension:
            .systemExtension
        }
    }
}

//
//  ProjectType+XcodeProductType.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import Core
import XcodeProjectManagement

extension ProductType {
    init?(xcodeProductType: XcodeProductType) {
        switch xcodeProductType {
        case .none:
            self = .none
        case .application:
            self = .application
        case .framework:
            self = .framework
        case .staticFramework:
            self = .staticLibrary
        case .xcFramework:
            self = .framework
        case .dynamicLibrary:
            self = .dynamicLibrary
        case .staticLibrary:
            self = .staticLibrary
        case .bundle:
            self = .bundle
        case .unitTestBundle:
            self = .unitTestBundle
        case .uiTestBundle:
            self = .uiTestBundle
        case .appExtension:
            self = .appExtension
        case .extensionKitExtension:
            self = .extensionKitExtension
        case .commandLineTool:
            self = .commandLineTool
        case .watchApp:
            self = .watchApp
        case .watch2App:
            self = .watch2App
        case .watch2AppContainer:
            self = .watch2AppContainer
        case .watchExtension:
            self = .watchExtension
        case .watch2Extension:
            self = .watch2Extension
        case .tvExtension:
            self = .tvExtension
        case .messagesApplication:
            self = .messagesApplication
        case .messagesExtension:
            self = .messagesExtension
        case .stickerPack:
            self = .stickerPack
        case .xpcService:
            self = .xpcService
        case .ocUnitTestBundle:
            self = .ocUnitTestBundle
        case .xcodeExtension:
            self = .xcodeExtension
        case .instrumentsPackage:
            self = .instrumentsPackage
        case .intentsServiceExtension:
            self = .intentsServiceExtension
        case .onDemandInstallCapableApplication:
            self = .onDemandInstallCapableApplication
        case .metalLibrary:
            self = .metalLibrary
        case .driverExtension:
            self = .driverExtension
        case .systemExtension:
            self = .systemExtension
        }
    }
}

//
//  ProjectInfo+XcodeProjectInfo.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import Core
import Foundation
import XcodeProjectManagement

extension XcodeProjectInfo {
    func asProjectInfo() -> ProjectInfo {
        ProjectInfo(
            rootURL: rootURL,
            name: name,
            targets: xcodeTargets.map { $0.asProjectTarget() },
            buildSettingsForIndex: [:],
            projectBuildSettings: xcodeProjectBuildSettings.asProjectBuildSettings()
        )
    }
}

extension XcodeTarget {
    func asProjectTarget() -> ProjectTarget {
        ProjectTarget(
            targetIndentifier: targetIdentifier,
            name: name,
            isSourcesResolved: false,
            isDependenciesResolved: false,
            sourceFiles: [],
            dependencies: [],
            productType: xcodeProductType.asProductType
        )
    }

    var targetIdentifier: String {
        "xcode://\(projectURL.path)/\(name)"
    }
}

extension XcodeProjectProjectBuildSettings {
    func asProjectBuildSettings() -> ProjectBuildSettings {
        ProjectBuildSettings(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL,
            configuration: configuration
        )
    }
}

extension XcodeProductType {
    var asProductType: ProductType {
        switch self {
        case .none:
            .none
        case .application:
            .application
        case .framework:
            .framework
        case .staticFramework:
            .staticFramework
        case .xcFramework:
            .xcFramework
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
            .messagesExtension
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

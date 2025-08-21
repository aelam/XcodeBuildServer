//
//  BSPBuildTarget+ProjectTarget.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/21.
//

import Foundation

extension ProductType {
    static let canCompileProductTypes: Set<ProductType> = Set(ProductType.allCases)
    static let canTestProductTypes: Set<ProductType> = [.unitTestBundle, .uiTestBundle, .ocUnitTestBundle]
    static let canRunProductTypes: Set<ProductType> = [
        .application, .appExtension, .commandLineTool,
        .watchApp, .watch2App, .watchExtension,
        .watch2Extension, .watch2AppContainer, .messagesApplication
    ]
    static let canDebugProductTypes = canCompileProductTypes
    var capabilities: BuildTargetCapabilities {
        BuildTargetCapabilities(
            canCompile: Self.canCompileProductTypes.contains(self),
            canTest: Self.canTestProductTypes.contains(self),
            canRun: Self.canRunProductTypes.contains(self),
            canDebug: Self.canDebugProductTypes.contains(self)
        )
    }
}

extension BSPBuildTarget {
    init?(projectTarget: ProjectTarget) {
        guard let id = try? BSPBuildTargetIdentifier(uri: URI(string: projectTarget.targetIndentifier)) else {
            return nil
        }
        self.id = id
        self.displayName = projectTarget.name
        self.baseDirectory = nil
        self.capabilities = projectTarget.productType.capabilities
        self.dataKind = .sourceKit

        if projectTarget.isSourcesResolved {
            let languages = projectTarget.sourceFiles.map {
                Language(inferredFromFileExtension: $0)
            }.compactMap { $0 }
            self.languageIds = Array(Set(languages))
        } else {
            self.languageIds = []
        }
        self.tags = []
        if projectTarget.isDependenciesResolved {
            self.dependencies = projectTarget.dependencies.compactMap {
                try? BSPBuildTargetIdentifier(uri: URI(string: $0.targetIndentifier))
            }
        } else {
            self.dependencies = []
        }
    }
}

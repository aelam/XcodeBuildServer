//
//  ProjectProviderRegistry.swift
//  BSPServer Module
//
//  Copyright © 2024 Wang Lun.
//

import Core
import Foundation
import SwiftPMProjectProvider

#if os(macOS)
import XcodeProjectProvider
#endif

/// 全局Provider注册器
/// 根据平台自动注册可用的Provider
public enum ProjectProviderRegistry {
    /// 获取所有可用的Provider
    public static func getAllProviders() -> [any ProjectManagerProvider] {
        var providers: [any ProjectManagerProvider] = []

        // 总是注册SwiftPM支持
        providers.append(SwiftPMProjectProvider())

        #if os(macOS)
        // 只在macOS上注册Xcode支持
        providers.append(XcodeProjectProvider())
        #endif

        return providers
    }

    /// 创建配置好的ProjectManagerFactory
    public static func createFactory() async -> ProjectManagerFactory {
        let factory = ProjectManagerFactory()

        for provider in getAllProviders() {
            await factory.registerProvider(provider)
        }

        return factory
    }
}

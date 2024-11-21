//
//  BuildSettings.swift
//
//  Copyright © 2024 Wang Lun.
//

struct BuildSettings: Decodable {
    let target: String
    let action: String
    let buildSettings: [String: String]
}

enum LanguageDialect: String, Decodable {
    case swift = "Xcode.SourceCodeLanguage.Swift"
    case objc = "Xcode.SourceCodeLanguage.Objective-C"
    case interfaceBuilder = "Xcode.SourceCodeLanguage.InterfaceBuilder"
    case other
}

typealias BuildSettingsForIndex = [String: [String: FileBuildSettingInfoForIndex]]

struct FileBuildSettingInfoForIndex: Decodable {
    var assetSymbolIndexPath: String?
    var LanguageDialect: LanguageDialect
    var outputFilePath: String?
    var swiftASTBuiltProductsDir: String?
    var swiftASTCommandArguments: [String]?
    var swiftASTModuleName: String?
    var toolchains: [String]?
}

extension BuildSettingsForIndex {
    func fileBuildInfo(for target: String, fileName: String) -> FileBuildSettingInfoForIndex? {
        guard let targetBuildSettings = self[target] else {
            return nil
        }
        return targetBuildSettings[fileName]
    }
}

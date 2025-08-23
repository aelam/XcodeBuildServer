protocol SourceFileBuildConfigurable {
    var targetBuildSettings: TargetBuildSettings { get }
    var sourceFile: String { get }
    var language: XcodeLanguageDialect { get }
    var outputFilePath: String { get }

    var ASTModuleName: String? { get } // For Swift
    var ASTBuiltProductsDir: String { get }
    var ASTCommandArguments: [String] { get }
}

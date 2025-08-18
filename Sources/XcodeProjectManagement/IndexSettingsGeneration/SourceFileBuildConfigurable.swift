
protocol SourceFileBuildConfigurable {
    var targetBuildConfig: TargetBuildConfig { get }
    var sourceFile: String { get }
    var language: XcodeLanguageDialect { get }
    var outputFilePath: String { get }

    var ASTModuleName: String? { get }
    var ASTBuiltProductsDir: String { get }
    var ASTCommandArguments: [String] { get }
}

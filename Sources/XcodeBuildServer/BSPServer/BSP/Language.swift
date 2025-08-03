//
//  Language.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// A source code language identifier, such as "swift", or "objective-c".
public struct Language: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public typealias LanguageId = String

    public let rawValue: LanguageId
    public init(rawValue: LanguageId) {
        self.rawValue = rawValue
    }

    /// Clang-compatible language name suitable for use with `-x <language>`.
    public var xflag: String? {
        switch self {
        case .swift: "swift"
        case .c: "c"
        case .cpp: "c++"
        case .objective_c: "objective-c"
        case .objective_cpp: "objective-c++"
        default: nil
        }
    }

    /// Clang-compatible language name for a header file. See `xflag`.
    public var xflagHeader: String? {
        xflag.map { "\($0)-header" }
    }
}

extension Language: CustomStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String {
        rawValue
    }

    public var description: String {
        switch self {
        case .abap: "ABAP"
        case .bat: "Windows Bat"
        case .bibtex: "BibTeX"
        case .clojure: "Clojure"
        case .coffeescript: "Coffeescript"
        case .c: "C"
        case .cpp: "C++"
        case .csharp: "C#"
        case .css: "CSS"
        case .diff: "Diff"
        case .dart: "Dart"
        case .dockerfile: "Dockerfile"
        case .fsharp: "F#"
        case .git_commit: "Git (commit)"
        case .git_rebase: "Git (rebase)"
        case .go: "Go"
        case .groovy: "Groovy"
        case .handlebars: "Handlebars"
        case .html: "HTML"
        case .ini: "Ini"
        case .java: "Java"
        case .javaScript: "JavaScript"
        case .javaScriptReact: "JavaScript React"
        case .json: "JSON"
        case .latex: "LaTeX"
        case .less: "Less"
        case .lua: "Lua"
        case .makefile: "Makefile"
        case .markdown: "Markdown"
        case .objective_c: "Objective-C"
        case .objective_cpp: "Objective-C++"
        case .perl: "Perl"
        case .perl6: "Perl 6"
        case .php: "PHP"
        case .powershell: "Powershell"
        case .jade: "Pug"
        case .python: "Python"
        case .r: "R"
        case .razor: "Razor (cshtml)"
        case .ruby: "Ruby"
        case .rust: "Rust"
        case .scss: "SCSS (syntax using curly brackets)"
        case .sass: "SCSS (indented syntax)"
        case .scala: "Scala"
        case .shaderLab: "ShaderLab"
        case .shellScript: "Shell Script (Bash)"
        case .sql: "SQL"
        case .swift: "Swift"
        case .typeScript: "TypeScript"
        case .typeScriptReact: "TypeScript React"
        case .tex: "TeX"
        case .vb: "Visual Basic"
        case .xml: "XML"
        case .xsl: "XSL"
        case .yaml: "YAML"
        default: rawValue
        }
    }
}

public extension Language {
    static let abap = Language(rawValue: "abap")
    static let bat = Language(rawValue: "bat") // Windows Bat
    static let bibtex = Language(rawValue: "bibtex")
    static let clojure = Language(rawValue: "clojure")
    static let coffeescript = Language(rawValue: "coffeescript")
    static let c = Language(rawValue: "c")
    static let cpp = Language(rawValue: "cpp") // C++, not C preprocessor
    static let csharp = Language(rawValue: "csharp")
    static let css = Language(rawValue: "css")
    static let diff = Language(rawValue: "diff")
    static let dart = Language(rawValue: "dart")
    static let dockerfile = Language(rawValue: "dockerfile")
    static let fsharp = Language(rawValue: "fsharp")
    static let git_commit = Language(rawValue: "git-commit")
    static let git_rebase = Language(rawValue: "git-rebase")
    static let go = Language(rawValue: "go")
    static let groovy = Language(rawValue: "groovy")
    static let handlebars = Language(rawValue: "handlebars")
    static let html = Language(rawValue: "html")
    static let ini = Language(rawValue: "ini")
    static let java = Language(rawValue: "java")
    static let javaScript = Language(rawValue: "javascript")
    static let javaScriptReact = Language(rawValue: "javascriptreact")
    static let json = Language(rawValue: "json")
    static let latex = Language(rawValue: "latex")
    static let less = Language(rawValue: "less")
    static let lua = Language(rawValue: "lua")
    static let makefile = Language(rawValue: "makefile")
    static let markdown = Language(rawValue: "markdown")
    static let objective_c = Language(rawValue: "objective-c")
    static let objective_cpp = Language(rawValue: "objective-cpp")
    static let perl = Language(rawValue: "perl")
    static let perl6 = Language(rawValue: "perl6")
    static let php = Language(rawValue: "php")
    static let powershell = Language(rawValue: "powershell")
    static let jade = Language(rawValue: "jade")
    static let python = Language(rawValue: "python")
    static let r = Language(rawValue: "r")
    static let razor = Language(rawValue: "razor") // Razor (cshtml)
    static let ruby = Language(rawValue: "ruby")
    static let rust = Language(rawValue: "rust")
    static let scss = Language(rawValue: "scss") // SCSS (syntax using curly brackets)
    static let sass = Language(rawValue: "sass") // SCSS (indented syntax)
    static let scala = Language(rawValue: "scala")
    static let shaderLab = Language(rawValue: "shaderlab")
    static let shellScript = Language(rawValue: "shellscript") // Shell Script (Bash)
    static let sql = Language(rawValue: "sql")
    static let swift = Language(rawValue: "swift")
    static let typeScript = Language(rawValue: "typescript")
    static let typeScriptReact = Language(rawValue: "typescriptreact") // TypeScript React
    static let tex = Language(rawValue: "tex")
    static let vb = Language(rawValue: "vb") // Visual Basic
    static let xml = Language(rawValue: "xml")
    static let xsl = Language(rawValue: "xsl")
    static let yaml = Language(rawValue: "yaml")
}

package extension Language {
    init?(inferredFromFileExtension fileURL: URL) {
        // URL.pathExtension is only set for file URLs but we want to also infer a file extension for non-file URLs like
        // untitled:file.cpp
        let pathExtension = fileURL.pathExtension
        switch pathExtension {
        case "c": self = .c
        case "cpp", "cc", "cxx", "hpp": self = .cpp
        case "m": self = .objective_c
        case "mm", "h": self = .objective_cpp
        case "swift": self = .swift
        default: return nil
        }
    }
}

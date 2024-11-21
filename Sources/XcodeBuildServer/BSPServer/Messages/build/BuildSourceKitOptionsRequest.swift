//
//  BuildSourceKitOptionsRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

/**
 {
     "jsonrpc": "2.0",
     "method": "build\/sourceKitOptionsChanged",
     "params": {
         "updatedOptions": {
             "options": [
                 "-module-name",
                 "Hello",
                 "-Onone",
                 "-enforce-exclusivity=checked",
                 "\/Users\/ST22956\/work-vscode\/Hello\/Hello\/World\/Hello.swift",
                 "\/Users\/ST22956\/work-vscode\/Hello\/Hello\/World\/World.swift",
                 "\/Users\/ST22956\/work-vscode\/Hello\/Hello\/AppDelegate.swift",
                 "\/Users\/ST22956\/work-vscode\/Hello\/Hello\/SceneDelegate.swift",
                 "\/Users\/ST22956\/work-vscode\/Hello\/Hello\/ViewController.swift",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/DerivedSources\/GeneratedAssetSymbols.swift",
                 "-DDEBUG",
                 "-enable-bare-slash-regex",
                 "-enable-experimental-feature",
                 "DebugDescriptionMacro",
                 "-sdk",
                 "\/Applications\/Xcode.app\/Contents\/Developer\/Platforms\/iPhoneOS.platform\/Developer\/SDKs\/iPhoneOS18.1.sdk",
                 "-target",
                 "arm64-apple-ios18.0",
                 "-g",
                 "-module-cache-path",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/ModuleCache.noindex",
                 "-Xfrontend",
                 "-serialize-debugging-options",
                 "-profile-coverage-mapping",
                 "-profile-generate",
                 "-enable-testing",
                 "-index-store-path",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Index.noindex\/DataStore",
                 "-Xcc",
                 "-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG",
                 "-swift-version",
                 "5",
                 "-Xcc",
                 "-I",
                 "-Xcc",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Products\/Debug-iphoneos",
                 "-I",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Products\/Debug-iphoneos",
                 "-Xcc",
                 "-F",
                 "-Xcc",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Products\/Debug-iphoneos",
                 "-F",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Products\/Debug-iphoneos",
                 "-emit-localized-strings",
                 "-emit-localized-strings-path",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/Objects-normal\/arm64",
                 "-c",
                 "-j10",
                 "-enable-batch-mode",
                 "-Xcc",
                 "-ivfsstatcache",
                 "-Xcc",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/SDKStatCaches.noindex\/iphoneos18.1-22B74-456b5073a84ca8a40bffd5133c40ea2b.sdkstatcache",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/swift-overrides.hmap",
                 "-emit-const-values",
                 "-Xfrontend",
                 "-const-gather-protocols-file",
                 "-Xfrontend",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/Objects-normal\/arm64\/Hello_const_extract_protocols.json",
                 "-Xcc",
                 "-iquote",
                 "-Xcc",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/Hello-generated-files.hmap",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/Hello-own-target-headers.hmap",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/Hello-all-target-headers.hmap",
                 "-Xcc",
                 "-iquote",
                 "-Xcc",
                 "\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/Hello-project-headers.hmap",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Products\/Debug-iphoneos\/include",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/DerivedSources-normal\/arm64",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/DerivedSources\/arm64",
                 "-Xcc",
                 "-I\/Users\/ST22956\/Library\/Developer\/Xcode\/DerivedData\/Hello-fcuisfeafkcytvbjerdcxvnpmzxn\/Build\/Intermediates.noindex\/Hello.build\/Debug-iphoneos\/Hello.build\/DerivedSources",
                 "-Xcc",
                 "-DDEBUG=1",
                 "-working-directory",
                 "\/Users\/ST22956\/work-vscode\/Hello",
                 "-Xcc",
                 "-fretain-comments-from-system-headers",
                 "-Xcc",
                 "-Xclang",
                 "-Xcc",
                 "-detailed-preprocessing-record",
                 "-Xcc",
                 "-Xclang",
                 "-Xcc",
                 "-fmodule-format=raw",
                 "-Xcc",
                 "-Xclang",
                 "-Xcc",
                 "-fallow-pch-with-compiler-errors",
                 "-Xcc",
                 "-Wno-non-modular-include-in-framework-module",
                 "-Xcc",
                 "-Wno-incomplete-umbrella",
                 "-Xcc",
                 "-fmodules-validate-system-headers"
             ],
             "workingDirectory": "\/Users\/ST22956\/work-vscode\/Hello\/"
         },
         "uri": "file:\/\/\/Users\/ST22956\/work-vscode\/Hello\/Hello\/World\/World.swift"
     }
 }
 */

/// The `TextDocumentSourceKitOptionsRequest` request is sent from the client to the server to query for the list of
/// compiler options necessary to compile this file in the given target.
///
/// The build settings are considered up-to-date and can be cached by SourceKit-LSP until a
/// `DidChangeBuildTargetNotification` is sent for the requested target.
///
/// The request may return `nil` if it doesn't have any build settings for this file in the given target.
public struct BuildSourceKitOptionsRequest: RequestType, @unchecked Sendable {
    public struct Params: Codable, Sendable {
        public struct UpdateOptions: Codable, Sendable {
            public let options: [String]
            public let workingDirectory: String?
        }

        /// The URI of the document to get options for
        public var textDocument: String // TextDocumentIdentifier

        /// The target for which the build setting should be returned.
        ///
        /// A source file might be part of multiple targets and might have different compiler arguments in those two targets,
        /// thus the target is necessary in this request.
        public var target: String // BuildTargetIdentifier

        /// The language with which the document was opened in the editor.
        public var language: Language
    }

    public static let method: String = "build/sourceKitOptions"

    public let id: JSONRPCID
    public let jsonrpc: String
    public let params: Params

    public func handle(
        _ handler: any MessageHandler,
        id _: RequestID
    ) async -> ResponseType? {
        guard handler is XcodeBSPMessageHandler else {
            return nil
        }
        return nil
    }
}

public struct BuildSourceKitOptionsResponse: ResponseType, Hashable {
    public struct Result: Codable, Hashable, Sendable {
        /// The compiler options required for the requested file.
        public let compilerArguments: [String]

        /// The working directory for the compile command.
        public let workingDirectory: String?
    }

    public var jsonrpc: String
    public let id: JSONRPCID?
    public let result: Result?
}

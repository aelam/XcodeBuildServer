
---

## 📌 CompilerFlagsProviders 清单

### 1. 平台相关 (Platform)
| Provider | 输入 Build Settings | 输出 Flags |
|----------|---------------------|------------|
| **SDKProvider** | `SDKROOT` | Swift: `-sdk`, Clang: `-isysroot` |
| **ArchProvider** | `ARCHS` | `-arch arm64`, `-arch x86_64` |
| **TargetTripleProvider** | `ARCHS`, `SDKROOT`, `IPHONEOS_DEPLOYMENT_TARGET`, `MACOSX_DEPLOYMENT_TARGET`, … | `-target arm64-apple-ios18.0-simulator` |
| **DeploymentTargetProvider** | 平台 Deployment Target | 已用于 triple 或单独暴露 |

### 2. 编译选项 (Compiler Options)
| Provider | 输入 Build Settings | 输出 Flags |
|----------|---------------------|------------|
| **OptimizationProvider** | `SWIFT_OPTIMIZATION_LEVEL`, `GCC_OPTIMIZATION_LEVEL` | `-Onone`, `-O2`, `-Os`，附带 `-enforce-exclusivity` |
| **LanguageStandardProvider** | `CLANG_CXX_LANGUAGE_STANDARD`, `CLANG_C_LANGUAGE_STANDARD`, `SWIFT_VERSION` | `-std=c++17`, `-std=c11`, `-swift-version 5` |
| **DebugInfoProvider** | `DEBUG_INFORMATION_FORMAT`, `GCC_GENERATE_DEBUGGING_SYMBOLS` | `-g`, `-gdwarf-2` |
| **ClangWarningProvider** | `CLANG_WARN_*` | `-Wdocumentation`, `-Wempty-body`, … |
| **GCCWarningProvider** | `GCC_WARN_*` | `-Wunused-variable`, `-Wshadow`, `-Werror`, … |
| **SwiftSpecificProvider** | `ENABLE_TESTABILITY`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, `SWIFT_ENABLE_BATCH_MODE` | `-enable-testing`, `-DDEBUG`, `-enable-batch-mode` |

### 3. 搜索路径 (Search Paths)
| Provider | 输入 Build Settings | 输出 Flags |
|----------|---------------------|------------|
| **HeaderSearchPathProvider** | `HEADER_SEARCH_PATHS`, `USER_HEADER_SEARCH_PATHS`, `SYSTEM_HEADER_SEARCH_PATHS` | `-I`, `-iquote`, `-isystem` |
| **FrameworkSearchPathProvider** | `FRAMEWORK_SEARCH_PATHS` | `-F` |
| **LibrarySearchPathProvider** | `LIBRARY_SEARCH_PATHS` | `-L` |
| **ModuleProvider** | `CLANG_ENABLE_MODULES`, `PRODUCT_MODULE_NAME`, `PRODUCT_NAME` | `-fmodules`, `-fmodule-name Foo` |

### 4. 链接相关 (Linking)
| Provider | 输入 Build Settings | 输出 Flags |
|----------|---------------------|------------|
| **LinkerProvider** | `OTHER_LDFLAGS`, `EXPORTED_SYMBOLS_FILE`, `DEAD_CODE_STRIPPING`, `LD_RUNPATH_SEARCH_PATHS` | `-lFoo`, `-exported_symbols_list`, `-Wl,-dead_strip`, `-rpath …` |
| **BitcodeProvider** | `ENABLE_BITCODE` | `-fembed-bitcode`, `-fno-embed-bitcode` |

### 5. 宏 / 代码生成 (Defines & Codegen)
| Provider | 输入 Build Settings | 输出 Flags |
|----------|---------------------|------------|
| **DefinesProvider** | `GCC_PREPROCESSOR_DEFINITIONS`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | `-DDEBUG`, `-DFOO=1` |
| **BridgingHeaderProvider** | `SWIFT_OBJC_BRIDGING_HEADER` | `-import-objc-header …` |
| **ObjCProvider** | `CLANG_ENABLE_OBJC_ARC` | `-fobjc-arc`, `-fno-objc-arc` |

### 6. 工具链与产物 (Toolchain & DerivedData)
| Provider | 输入 Build Settings | 输出 Flags |
|----------|---------------------|------------|
| **ToolchainProvider** | `TOOLCHAIN_DIR` | `-toolchain com.apple.dt.toolchain.XcodeDefault` |
| **IndexStoreProvider** | `INDEX_STORE_PATH`（或 DerivedData 推导） | `-index-store-path …` |
| **ModuleCacheProvider** | `MODULE_CACHE_DIR`（或 DerivedData 默认值） | `-module-cache-path …` |
| **OutputProvider** | `OBJECT_FILE_DIR`, `DERIVED_FILE_DIR` | `-o file.o`, `-emit-objc-header-path …` |

---

## 🎯 架构流程

```mermaid
flowchart TD
    A[XcodeProj .pbxproj] --> B[BuildSettingResolver]
    B --> C{Resolved Build Settings<br/>[String:String]}
    C --> D1[SDKProvider]
    C --> D2[ArchProvider]
    C --> D3[TargetTripleProvider]
    C --> D4[OptimizationProvider]
    C --> D5[LanguageStandardProvider]
    C --> D6[DebugInfoProvider]
    C --> D7[ClangWarningProvider]
    C --> D8[GCCWarningProvider]
    C --> D9[SearchPath Providers<br/>(Header/Framework/Library)]
    C --> D10[ModuleProvider]
    C --> D11[LinkerProvider]
    C --> D12[BitcodeProvider]
    C --> D13[DefinesProvider]
    C --> D14[BridgingHeaderProvider]
    C --> D15[ObjCProvider]
    C --> D16[ToolchainProvider]
    C --> D17[IndexStoreProvider]
    C --> D18[ModuleCacheProvider]
    C --> D19[OutputProvider]

    D1 --> E[CompilerArgumentsBuilder]
    D2 --> E
    D3 --> E
    D4 --> E
    D5 --> E
    D6 --> E
    D7 --> E
    D8 --> E
    D9 --> E
    D10 --> E
    D11 --> E
    D12 --> E
    D13 --> E
    D14 --> E
    D15 --> E
    D16 --> E
    D17 --> E
    D18 --> E
    D19 --> E

    E --> F[Final Compiler Arguments]
```

## ✅ 总结

完整覆盖 `buildSettingsForIndex` 的 Providers 分类：

- **平台信息**：SDK / Arch / TargetTriple / DeploymentTarget  
- **编译选项**：Optimization / LanguageStandard / DebugInfo / Warnings / Swift 特性  
- **搜索路径**：Header / Framework / Library / Module  
- **链接**：Linker / Bitcode  
- **宏与代码生成**：Defines / BridgingHeader / ObjC  
- **工具链 & DerivedData**：Toolchain / IndexStore / ModuleCache / Output  

---
EOF

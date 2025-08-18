# 新版 Xcode 项目文件 Target 文件归属与变更判断

## 背景

Xcode 15 及以后版本的 `.xcodeproj` 项目文件结构发生了变化，源文件归属不再依赖 `PBXFileReference`，而是通过 `PBXFileSystemSynchronizedRootGroup` 自动同步文件夹内容。每个 target 通过 `fileSystemSynchronizedGroups` 字段绑定到实际的文件夹，实现自动文件归属和变更检测。

---

## 关键结构

- **PBXNativeTarget**
  - `fileSystemSynchronizedGroups`：指向分组 ID
- **PBXFileSystemSynchronizedRootGroup**
  - `path`：分组对应的物理文件夹路径

---

## 文件变更归属判断流程

1. **解析所有 target 及其绑定的文件夹**
   - 读取 pbxproj，获取每个 target 的 `fileSystemSynchronizedGroups`
   - 通过分组的 `path` 字段，得到 target 绑定的文件夹路径

2. **收到文件变更通知后**
   - 遍历所有变更的文件路径
   - 对每个 target，判断文件路径是否在 target 绑定的文件夹（或其子目录）下

3. **归属判定**
   - 如果文件路径属于某个 target 的文件夹，则认为该 target 的文件发生了改变
   - 多 target 绑定同一文件夹时，所有相关 target 都会被判定为变更

---

## 示例伪代码

```swift
for fileURL in changedFiles {
    for target in allTargets {
        if fileURL.isDescendant(of: target.folderURL) {
            // 该 target 的文件发生了改变
            notifyTargetChanged(target, fileURL)
        }
    }
}
```

---

## 兼容性注意

- 如果 `.xcodeproj` 文件版本低于 13.0（Xcode 15 之前），请跳过此自动归属逻辑，使用旧的 file ref 机制。

---

## 总结

新版 Xcode 项目文件通过分组与文件夹自动同步，实现了 target 文件归属的自动化。只需解析 pbxproj 的分组和 target 绑定关系，即可高效判断文件变更归属，无需手动维护 file ref。

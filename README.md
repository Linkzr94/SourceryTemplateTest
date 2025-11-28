# EGSourceryTemplate

一个用于共享 Sourcery 模板的 Swift Package，支持在多个 SPM 组件化项目中复用代码生成模板。

## 功能特性

- 📦 提供共享的 Sourcery 模板
- 🔌 通过 Swift Package Plugin 自动查找模板路径
- 🎯 支持 Git 依赖、Path 依赖、Monorepo 等多种场景
- ⚡️ 无需手动配置模板路径，自动适配

## 安装

在你的项目的 `Package.swift` 中添加依赖：

### Git 依赖方式

```swift
dependencies: [
    .package(url: "https://github.com/your-org/EGSourceryTemplate.git", from: "1.0.0")
]
```

### Path 依赖方式（本地开发）

```swift
dependencies: [
    .package(path: "../EGSourceryTemplate")
]
```

## 使用方式

### 1. 基本使用

在任意依赖了 `EGSourceryTemplate` 的项目根目录下执行：

```bash
swift package plugin --allow-writing-to-package-directory eg-sourcery
```

**⚠️ 重要：** Command Plugin 需要写入权限才能生成代码到 `Sources` 目录。首次运行会提示授权，或者使用 `--allow-writing-to-package-directory` 参数直接授权。

**默认行为：**
- 扫描源文件：`Sources/` 目录
- 使用模板：自动查找 `EGSourceryTemplate` 的模板
- 输出路径：`Sources/Generated/`

### 2. 自定义路径

```bash
# 指定源文件路径
swift package plugin --allow-writing-to-package-directory eg-sourcery \
  --sources Sources/MyModule

# 指定输出路径
swift package plugin --allow-writing-to-package-directory eg-sourcery \
  --output Sources/MyModule/Generated

# 同时指定多个参数
swift package plugin --allow-writing-to-package-directory eg-sourcery \
  --sources Sources/MyModule \
  --output Sources/MyModule/Generated
```

### 3. 使用配置文件（推荐）

Plugin 会自动检测项目根目录的 `.sourcery.yml` 配置文件：

#### 创建 `.sourcery.yml`

```yaml
# .sourcery.yml
sources:
  - Sources/MyModule
output:
  Sources/Generated
exclude:
  - Sources/Tests
```

#### 运行

```bash
swift package plugin --allow-writing-to-package-directory eg-sourcery
```

Plugin 会自动：
1. 发现 `.sourcery.yml` 配置文件
2. 读取你的 `sources` 和 `output` 配置
3. **自动注入模板路径**（无需在配置文件中指定 `templates`）

#### 指定自定义配置文件

```bash
swift package plugin --allow-writing-to-package-directory eg-sourcery \
  --config path/to/custom.yml
```

### 4. 传递额外参数给 Sourcery

```bash
swift package plugin --allow-writing-to-package-directory eg-sourcery --verbose
```

## 模板说明

目前包含的模板：

### AutoEquatable

为标记了 `// sourcery: AutoEquatable` 的类型自动生成 `Equatable` 实现。

**使用示例：**

```swift
// sourcery: AutoEquatable
struct User {
    let id: String
    let name: String
    let age: Int
}
```

**生成的代码：**

```swift
extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        guard lhs.id == rhs.id else { return false }
        guard lhs.name == rhs.name else { return false }
        guard lhs.age == rhs.age else { return false }
        return true
    }
}
```

## 添加自定义模板

1. 在 `Sources/EGSourceryTemplate/Templates/` 目录下添加 `.stencil` 文件
2. 模板会自动被 Plugin 发现和使用

## 在 Xcode 项目中使用

如果你在 Xcode 中打开了 SPM 项目：

1. 右键点击项目
2. 选择 "EGSourceryPlugin"
3. 点击运行

或者添加到 Build Phases 中实现自动化（需要手动配置）。

## 工作原理

### 为什么需要 Plugin？

在 SPM 组件化项目中，模板库的路径会根据依赖方式不同而变化：

- **Git 依赖**: `.build/checkouts/EGSourceryTemplate/...`
- **Path 依赖**: `../EGSourceryTemplate/...`
- **同一 repo 多 package**: 相对路径

Plugin 可以在运行时动态查找模板路径，无论使用哪种依赖方式都能正常工作。

### 路径查找逻辑

1. 检查当前 package 是否就是 `EGSourceryTemplate`（用于测试模板）
2. 遍历所有依赖，查找包含模板目录的 package
3. 自动解析并传递给 Sourcery

## 常见问题

### Q: 为什么不直接在 `.sourcery.yml` 中写死模板路径？

A: 因为不同的依赖方式（git/path/monorepo）会导致路径不同，写死路径会导致切换依赖方式时配置失效。

### Q: 可以在多个 target 中使用吗？

A: 可以，在每个 target 的根目录执行 plugin 命令即可，或者通过 `--sources` 参数指定不同的 target。

### Q: 生成的代码需要提交到 Git 吗？

A: 建议提交，这样其他开发者拉取代码后可以直接编译，不需要先运行代码生成。

## License

MIT

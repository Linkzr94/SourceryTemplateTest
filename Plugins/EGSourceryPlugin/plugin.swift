import Foundation
import PackagePlugin

@main
struct EGSourceryPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        // 获取 sourcery 工具路径
        let sourceryTool = try context.tool(named: "sourcery")

        // 查找模板目录
        let templatesPath = try findTemplatesPath(in: context)

        print("📦 EGSourceryTemplate Plugin")
        print("📁 Templates path: \(templatesPath)")
        print("🔧 Sourcery tool: \(sourceryTool.path)")

        // 解析参数
        var argumentExtractor = ArgumentExtractor(arguments)

        // 配置文件路径：优先使用命令行参数，其次自动检测 .sourcery.yml
        let configPath: String? = {
            if let explicitConfig = argumentExtractor.extractOption(named: "config").first {
                return explicitConfig
            }

            // 自动查找 .sourcery.yml
            let autoConfigPath = context.package.directory.appending(".sourcery.yml")
            if FileManager.default.fileExists(atPath: autoConfigPath.string) {
                return autoConfigPath.string
            }

            return nil
        }()

        // 构建 sourcery 命令参数
        var sourceryArgs: [String] = []

        if let configPath = configPath {
            // 使用配置文件模式
            sourceryArgs = ["--config", configPath]

            // 始终注入模板路径，这样用户配置文件中无需指定 templates
            sourceryArgs += ["--templates", templatesPath]

            print("🚀 Running Sourcery with config file...")
            print("   Config: \(configPath)")
            print("   Templates: \(templatesPath) (auto-injected)")
        } else {
            // 命令行参数模式
            let sources = argumentExtractor.extractOption(named: "sources").first
                ?? context.package.directory.appending("Sources").string

            let output = argumentExtractor.extractOption(named: "output").first
                ?? context.package.directory.appending("Sources/Generated").string

            sourceryArgs = [
                "--sources", sources,
                "--templates", templatesPath,
                "--output", output,
                "--verbose"
            ]

            print("🚀 Running Sourcery with command-line args...")
            print("   Sources: \(sources)")
            print("   Templates: \(templatesPath)")
            print("   Output: \(output)")
        }

        // 禁用缓存以避免沙箱权限问题
        sourceryArgs.append("--disableCache")

        // 添加其他参数（过滤掉 SPM plugin 系统参数）
        let remainingArgs = filterPluginSystemArguments(argumentExtractor.remainingArguments)
        sourceryArgs += remainingArgs

        // 执行 sourcery
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sourceryTool.path.string)
        process.arguments = sourceryArgs
        
        print("process: \(process.executableURL)")
        print("args: \(sourceryArgs)")

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("✅ Code generation completed successfully!")
        } else {
            print("❌ Code generation failed with status: \(process.terminationStatus)")
            throw PluginError.sourceryFailed
        }
    }

    /// 过滤掉 SPM plugin 系统参数，只保留应该传递给 Sourcery 的参数
    private func filterPluginSystemArguments(_ arguments: [String]) -> [String] {
        var filtered: [String] = []
        var skipNext = false

        for arg in arguments {
            if skipNext {
                skipNext = false
                continue
            }

            // 过滤掉 SPM plugin 系统参数
            if arg == "--target" || arg == "--package-path" || arg == "--allow-writing-to-package-directory" {
                skipNext = true // 跳过下一个参数（这些选项的值）
                continue
            }

            filtered.append(arg)
        }

        return filtered
    }

    /// 查找 EGSourceryTemplate 的模板目录
    private func findTemplatesPath(in context: PluginContext) throws -> String {
        // 尝试在当前 package 中查找（如果是 EGSourceryTemplate 自己）
        let localTemplatesPath = context.package.directory.appending("Sources/EGSourceryTemplate/Templates")
        if FileManager.default.fileExists(atPath: localTemplatesPath.string) {
            return localTemplatesPath.string
        }

        // 在依赖中查找
        for dependency in context.package.dependencies {
            let dependencyPath = dependency.package.directory
            let templatesPath = dependencyPath.appending("Sources/EGSourceryTemplate/Templates")

            if FileManager.default.fileExists(atPath: templatesPath.string) {
                return templatesPath.string
            }
        }

        throw PluginError.templatesNotFound
    }
}

enum PluginError: Error, CustomStringConvertible {
    case templatesNotFound
    case sourceryFailed

    var description: String {
        switch self {
        case .templatesNotFound:
            return "Could not find EGSourceryTemplate templates directory"
        case .sourceryFailed:
            return "Sourcery execution failed"
        }
    }
}

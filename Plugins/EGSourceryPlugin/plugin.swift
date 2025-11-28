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
        print("🔧 Sourcery tool: \(sourceryTool.url.path)")

        // 解析参数
        var argumentExtractor = ArgumentExtractor(arguments)

        // 配置文件路径：优先使用命令行参数，其次自动检测 .sourcery.yml
        let configPath: String? = {
            if let explicitConfig = argumentExtractor.extractOption(named: "config").first {
                return explicitConfig
            }

            // 自动查找 .sourcery.yml
            let autoConfigPath = context.package.directoryURL.appending(path: ".sourcery.yml")
            if FileManager.default.fileExists(atPath: autoConfigPath.path()) {
                return autoConfigPath.path()
            }

            return nil
        }()

        // 构建 sourcery 命令参数
        var sourceryArgs: [String] = []

        if let configPath = configPath {
            // 使用配置文件模式
            // 注意：Sourcery 使用 --config 时会忽略命令行参数
            // 所以需要读取配置文件，注入 templates，生成临时配置文件

            let tempConfigPath = try injectTemplatesIntoConfig(
                originalConfig: configPath,
                templatesPath: templatesPath,
                in: context
            )

            sourceryArgs = ["--config", tempConfigPath]

            print("🚀 Running Sourcery with config file...")
            print("   Config: \(configPath)")
            print("   Templates: \(templatesPath) (auto-injected)")
        } else {
            // 命令行参数模式
            let sources = argumentExtractor.extractOption(named: "sources").first
                ?? context.package.directoryURL.appending(path: "Sources").path()

            let output = argumentExtractor.extractOption(named: "output").first
                ?? context.package.directoryURL.appending(path: "Sources/Generated").path()

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
        process.executableURL = sourceryTool.url
        process.arguments = sourceryArgs

        print("process: \(process.executableURL?.path() ?? "nil")")
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

    /// 读取配置文件，注入 templates 路径，生成临时配置文件
    private func injectTemplatesIntoConfig(
        originalConfig: String,
        templatesPath: String,
        in context: PluginContext
    ) throws -> String {
        // 读取原始配置文件
        let configURL = URL(fileURLWithPath: originalConfig)
        var configContent = try String(contentsOf: configURL, encoding: .utf8)

        // 使用配置文件所在的目录作为基准目录（通常是项目根目录）
        // 这样相对路径会正确解析到项目的 Sources 目录
        let configDir = configURL.deletingLastPathComponent().path

        // 将配置文件中的相对路径转换为绝对路径
        // 这是必要的，因为临时配置文件会被放在不同的目录中
        configContent = convertRelativePathsToAbsolute(
            in: configContent,
            baseDir: configDir
        )

        // 检查是否已经有 templates 配置
        let hasTemplates = configContent.range(of: #"^\s*templates\s*:"#, options: .regularExpression) != nil

        var newConfigContent: String
        if hasTemplates {
            // 如果已经有 templates，在后面追加
            newConfigContent = configContent + "\n  - \(templatesPath)\n"
        } else {
            // 如果没有 templates，添加新的 templates 字段
            newConfigContent = configContent + "\ntemplates:\n  - \(templatesPath)\n"
        }

        // 创建临时配置文件
        let tempDir = context.pluginWorkDirectoryURL
        let tempConfigPath = tempDir.appending(path: "sourcery-temp.yml")
        try newConfigContent.write(toFile: tempConfigPath.path(), atomically: true, encoding: .utf8)

        return tempConfigPath.path()
    }

    /// 将 YAML 配置中的相对路径转换为绝对路径
    private func convertRelativePathsToAbsolute(in content: String, baseDir: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var convertedLines: [String] = []
        var isOutputSection = false

        for line in lines {
            var convertedLine = line
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 检测是否进入 output 节
            if line.range(of: #"^\s*output\s*:"#, options: .regularExpression) != nil {
                isOutputSection = true
                let colonRange = line.range(of: ":")!
                let pathPart = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                // 单行格式：output: path
                if !pathPart.isEmpty && !pathPart.hasPrefix("/") {
                    let absolutePath = URL(fileURLWithPath: baseDir)
                        .appendingPathComponent(pathPart)
                        .path
                    let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                    convertedLine = "\(leadingWhitespace)output: \(absolutePath)"
                    isOutputSection = false
                }
            }
            // 处理 output 下的路径（多行格式）
            else if isOutputSection && !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") {
                isOutputSection = false  // output 只有一个值

                // 检查是否是路径行（不以 - 开头）
                if !trimmedLine.hasPrefix("-") && !trimmedLine.hasPrefix("/") {
                    let absolutePath = URL(fileURLWithPath: baseDir)
                        .appendingPathComponent(trimmedLine)
                        .path
                    let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                    convertedLine = "\(leadingWhitespace)\(absolutePath)"
                }
            }
            // 匹配列表路径：  - path/to/dir
            else if trimmedLine.hasPrefix("- ") {
                let pathPart = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)

                // 只转换相对路径（不以 / 开头，不是注释）
                if !pathPart.hasPrefix("/") && !pathPart.hasPrefix("#") && !pathPart.isEmpty {
                    let absolutePath = URL(fileURLWithPath: baseDir)
                        .appendingPathComponent(pathPart)
                        .path

                    // 保留原有的缩进
                    let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                    convertedLine = "\(leadingWhitespace)- \(absolutePath)"
                }
            }
            // 遇到新的顶级键（不以空格开头且有冒号）退出 output 节
            else if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                isOutputSection = false
            }

            convertedLines.append(convertedLine)
        }

        return convertedLines.joined(separator: "\n")
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
        let localTemplatesPath = context.package.directoryURL.appending(path: "Sources/EGSourceryTemplate/Templates")
        if FileManager.default.fileExists(atPath: localTemplatesPath.path()) {
            return localTemplatesPath.path()
        }

        // 在依赖中查找
        for dependency in context.package.dependencies {
            let dependencyPath = dependency.package.directoryURL
            let templatesPath = dependencyPath.appending(path: "Sources/EGSourceryTemplate/Templates")

            if FileManager.default.fileExists(atPath: templatesPath.path()) {
                return templatesPath.path()
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

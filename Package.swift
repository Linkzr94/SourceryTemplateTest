// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EGSourceryTemplate",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EGSourceryTemplate", targets: ["EGSourceryTemplate"]),
        .plugin(name: "EGSourceryPlugin", targets: ["EGSourceryPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzysztofzablocki/Sourcery.git", branch: "master")
    ],
    targets: [
        .target(
            name: "EGSourceryTemplate",
            resources: [
                .process("Templates")
            ]
        ),
        .plugin(
            name: "EGSourceryPlugin",
            capability: .command(
                intent: .custom(
                    verb: "eg-sourcery",
                    description: "Generate code using Sourcery templates from EGSourceryTemplate"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Sourcery needs to write generated code to the Sources directory")
                ]
            ),
            dependencies: [
                .product(name: "sourcery", package: "Sourcery")
            ]
        ),
    ]
)

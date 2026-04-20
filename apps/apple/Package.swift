// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TodoMacOS",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "TodoAPIClient", targets: ["TodoAPIClient"]),
        .executable(name: "TodoMacOS", targets: ["TodoMacOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.11.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "TodoAPIClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .executableTarget(
            name: "TodoMacOS",
            dependencies: ["TodoAPIClient"],
            path: "Sources/Todo/TodoMacOS",
            exclude: [
                "TodoMacOS.entitlements",
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Localizable.strings"),
            ]
        ),
    ]
)

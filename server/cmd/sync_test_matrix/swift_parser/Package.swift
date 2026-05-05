// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sync-test-matrix-swift-parser",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "sync-test-matrix-swift-parser",
            targets: ["SyncTestMatrixSwiftParser"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SyncTestMatrixSwiftParser",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
    ]
)

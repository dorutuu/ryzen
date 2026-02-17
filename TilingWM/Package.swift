// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TilingWM",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "tilingwm", targets: ["TilingWM"]),
        .executable(name: "twm", targets: ["TilingWMCLI"]),
        .library(name: "TilingWMLib", targets: ["TilingWMLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jdfergason/swift-toml", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "TilingWM",
            dependencies: [
                "TilingWMLib",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .executableTarget(
            name: "TilingWMCLI",
            dependencies: [
                "TilingWMLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "TilingWMLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "TilingWMTests",
            dependencies: ["TilingWMLib"]
        ),
    ]
)
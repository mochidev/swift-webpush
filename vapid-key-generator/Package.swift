// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let tool = Package(
    name: "vapid-key-generator",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .executable(name: "vapid-key-generator", targets: ["VAPIDKeyGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(path: "../"),
    ],
    targets: [
        .executableTarget(
            name: "VAPIDKeyGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "WebPush", package: "swift-webpush"),
            ]
        ),
    ]
)

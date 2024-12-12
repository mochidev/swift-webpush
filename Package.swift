// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-webpush",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(name: "WebPush", targets: ["WebPush"]),
        .library(name: "WebPushTesting", targets: ["WebPush", "WebPushTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "3.10.0"..<"5.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.77.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.6.2"),
    ],
    targets: [
        .target(
            name: "WebPush",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ]
        ),
        .target(
            name: "WebPushTesting",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .target(name: "WebPush"),
            ]
        ),
        .testTarget(name: "WebPushTests", dependencies: [
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .target(name: "WebPush"),
            .target(name: "WebPushTesting"),
        ]),
    ]
)

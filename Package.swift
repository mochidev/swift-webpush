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
        /// Core dependency that allows us to sign Authorization tokens and encrypt push messages per subscriber before delivery.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.10.0"..<"5.0.0"),
        /// Logging integration allowing runtime API missuse warnings and push status tracing.
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
        /// Service lifecycle integration for clean shutdowns in a server environment.
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.6.2"),
        /// Internal dependency allowing push message delivery over HTTP/2.
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
        /// Internal dependency for event loop coordination and shared HTTP types.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.77.0"),
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
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .target(name: "WebPush"),
            .target(name: "WebPushTesting"),
        ]),
    ]
)

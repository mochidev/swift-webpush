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
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "WebPush",
            dependencies: [
            ]
        ),
        .testTarget(name: "WebPushTests", dependencies: ["WebPush"]),
    ]
)

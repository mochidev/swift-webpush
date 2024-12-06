# WebPush

<p align="center">
    <a href="https://swiftpackageindex.com/mochidev/WebPush">
        <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmochidev%2FWebPush%2Fbadge%3Ftype%3Dswift-versions" />
    </a>
    <a href="https://swiftpackageindex.com/mochidev/WebPush">
        <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmochidev%2FWebPush%2Fbadge%3Ftype%3Dplatforms" />
    </a>
    <a href="https://github.com/mochidev/WebPush/actions?query=workflow%3A%22Test+WebPush%22">
        <img src="https://github.com/mochidev/WebPush/workflows/Test%20WebPush/badge.svg" alt="Test Status" />
    </a>
</p>

A server-side Swift implementation of the WebPush standard.

## Quick Links

- [Documentation](https://swiftpackageindex.com/mochidev/WebPush/documentation)
- [Updates on Mastodon](https://mastodon.social/tags/SwiftWebPush)

## Installation

Add `WebPush` as a dependency in your `Package.swift` file to start using it. Then, add `import WebPush` to any file you wish to use the library in.

Please check the [releases](https://github.com/mochidev/WebPush/releases) for recommended versions.

```swift
dependencies: [
    .package(
        url: "https://github.com/mochidev/WebPush.git", 
        .upToNextMinor(from: "0.0.1")
    ),
],
...
targets: [
    .target(
        name: "MyPackage",
        dependencies: [
            "WebPush",
        ]
    )
]
```

## Usage

TBD

## Contributing

Contribution is welcome! Please take a look at the issues already available, or start a new discussion to propose a new feature. Although guarantees can't be made regarding feature requests, PRs that fit within the goals of the project and that have been discussed beforehand are more than welcome!

Please make sure that all submissions have clean commit histories, are well documented, and thoroughly tested. **Please rebase your PR** before submission rather than merge in `main`. Linear histories are required, so merge commits in PRs will not be accepted.

## Support

To support this project, consider following [@dimitribouniol](https://mastodon.social/@dimitribouniol) on Mastodon, listening to Spencer and Dimitri on [Code Completion](https://mastodon.social/@codecompletion), or downloading Linh and Dimitri's apps:
- [Not Phở](https://notpho.app/)
- [Jiiiii](https://jiiiii.moe/)

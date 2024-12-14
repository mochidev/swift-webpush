# Swift WebPush

<p align="center">
    <a href="https://swiftpackageindex.com/mochidev/swift-webpush">
        <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmochidev%2Fswift-webpush%2Fbadge%3Ftype%3Dswift-versions" />
    </a>
    <a href="https://swiftpackageindex.com/mochidev/swift-webpush">
        <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmochidev%2Fswift-webpush%2Fbadge%3Ftype%3Dplatforms" />
    </a>
    <a href="https://github.com/mochidev/swift-webpush/actions?query=workflow%3A%22Test+WebPush%22">
        <img src="https://github.com/mochidev/swift-webpush/workflows/Test%20WebPush/badge.svg" alt="Test Status" />
    </a>
</p>

A server-side Swift implementation of the WebPush standard.

## Quick Links

- [Documentation](https://swiftpackageindex.com/mochidev/swift-webpush/documentation)
- [Updates on Mastodon](https://mastodon.social/tags/SwiftWebPush)

## Installation

Add `WebPush` as a dependency in your `Package.swift` file to start using it. Then, add `import WebPush` to any file you wish to use the library in.

Please check the [releases](https://github.com/mochidev/swift-webpush/releases) for recommended versions.

```swift
dependencies: [
    .package(
        url: "https://github.com/mochidev/swift-webPush.git", 
        .upToNextMinor(from: "0.1.1")
    ),
],
...
targets: [
    .target(
        name: "MyPackage",
        dependencies: [
            "WebPush",
        ]
    ),
    .testTarget(
        name: "MyPackageTests",
        dependencies: [
            "WebPushTesting",
        ]
    ),
]
```

## Usage

### Generating Keys

Before integrating WebPush into your server, you must generate one time VAPID keys to identify your server to push services with. To help we this, we provide `vapid-key-generator`, which you can install and use as needed:
```zsh
% git clone https://github.com/mochidev/swift-webpush.git
% cd swift-webpush/vapid-key-generator
% swift package experimental-install
```

To uninstall the generator:
```zsh
% package experimental-uninstall vapid-key-generator
```

Once installed, a new configuration can be generated as needed:
```
% ~/.swiftpm/bin/vapid-key-generator https://example.com
VAPID.Configuration: {"contactInformation":"https://example.com","expirationDuration":79200,"keys":["g7PXKzeMR/B+ndQWa92Dl9u22CibXJnm6vN9L6Gri1E="],"primaryKey":"g7PXKzeMR/B+ndQWa92Dl9u22CibXJnm6vN9L6Gri1E=","validityDuration":72000}


Example Usage:
    // TODO: Load this data from .env or from file system
    let configurationData = Data(#" {"contactInformation":"https://example.com","expirationDuration":79200,"keys":["g7PXKzeMR/B+ndQWa92Dl9u22CibXJnm6vN9L6Gri1E="],"primaryKey":"g7PXKzeMR/B+ndQWa92Dl9u22CibXJnm6vN9L6Gri1E=","validityDuration":72000} "#.utf8)
    let vapidConfiguration = try JSONDecoder().decode(VAPID.Configuration.self, from: configurationData)
```

Once generated, the configuration JSON should be added to your deployment's `.env` and kept secure so it can be accessed at runtime by your application server, and _only_ by your application server. Make sure this key does not leak and is not stored alongside subscriber information.

> [!NOTE]
> You can specify either a support URL or an email for administrators of push services to contact you with if problems are encountered, or you can generate keys only if you prefer to configure contact information at runtime:

```zsh
% ~/.swiftpm/bin/vapid-key-generator -h
OVERVIEW: Generate VAPID Keys.

Generates VAPID keys and configurations suitable for use on your server. Keys should generally only be generated once
and kept secure.

USAGE: vapid-key-generator <support-url>
       vapid-key-generator --email <email>
       vapid-key-generator --key-only

ARGUMENTS:
  <support-url>           The fully-qualified HTTPS support URL administrators of push services may contact you at:
                          https://example.com/support

OPTIONS:
  -k, --key-only          Only generate a VAPID key.
  -s, --silent            Output raw JSON only so this tool can be piped with others in scripts.
  -p, --pretty            Output JSON with spacing. Has no effect when generating keys only.
  --email <email>         Parse the input as an email address.
  -h, --help              Show help information.
```

> [!IMPORTANT]
> If you only need to change the contact information, you can do so in the JSON directly — a key should _not_ be regenerated when doing this as it will invalidate all existing subscriptions.

> [!TIP]
> If you prefer, you can also generate keys in your own code by calling `VAPID.Key()`, but remember, the key should be persisted and re-used from that point forward!

### Setup

TBD

## Contributing

Contribution is welcome! Please take a look at the issues already available, or start a new discussion to propose a new feature. Although guarantees can't be made regarding feature requests, PRs that fit within the goals of the project and that have been discussed beforehand are more than welcome!

Please make sure that all submissions have clean commit histories, are well documented, and thoroughly tested. **Please rebase your PR** before submission rather than merge in `main`. Linear histories are required, so merge commits in PRs will not be accepted.

## Support

To support this project, consider following [@dimitribouniol](https://mastodon.social/@dimitribouniol) on Mastodon, listening to Spencer and Dimitri on [Code Completion](https://mastodon.social/@codecompletion), or downloading Linh and Dimitri's apps:
- [Not Phở](https://notpho.app/)
- [Jiiiii](https://jiiiii.moe/)

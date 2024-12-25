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
- [Symbol Exploration](https://swiftinit.org/docs/mochidev.swift-webpush)
- [Updates on Mastodon](https://mastodon.social/tags/SwiftWebPush)

## Installation

Add `WebPush` as a dependency in your `Package.swift` file to start using it. Then, add `import WebPush` to any file you wish to use the library in.

Please check the [releases](https://github.com/mochidev/swift-webpush/releases) for recommended versions.

```swift
dependencies: [
    .package(
        url: "https://github.com/mochidev/swift-webpush.git", 
        .upToNextMinor(from: "0.4.0")
    ),
],
...
targets: [
    .target(
        name: "MyPackage",
        dependencies: [
            .product(name: "WebPush", package: "swift-webpush"),
            ...
        ]
    ),
    .testTarget(
        name: "MyPackageTests",
        dependencies: [
            .product(name: "WebPushTesting", package: "swift-webpush"),
            ...
        ]
    ),
]
```

## Usage

### Terminology and Core Concepts

If you are unfamiliar with the WebPush standard, we suggest you first familiarize yourself with the following core concepts:

<details>
<summary><strong>Subscriber</strong></summary>

A **Subscriber** represents a device that has opted in to receive push messages from your service. 

> [!IMPORTANT]
> A subscriber should not be conflated with a user — a single user may be logged in on multiple devices, while a subscriber may be shared by multiple users on a single device. It is up to you to manage this complexity and ensure user information remains secure across session boundaries by registering, unregistering, and updating the subscriber when a user logs in or out.

</details>

<details>
<summary><strong>Application Server</strong></summary>

The **Application Server** is a server you run to manage subscriptions and send push notifications. The actual servers that perform these roles may be different, but they must all use the same VAPID keys to function correctly.

> [!CAUTION]
> Using a VAPID key that wasn't registered with a subscription <strong>will</strong> result in push messages failing to reach their subscribers.

</details>

<details>
<summary><strong>VAPID Key</strong></summary>

**VAPID**, or _Voluntary Application Server Identification_, describes a standard for letting your application server introduce itself at time of subscription registration so that the subscription returned back to you may only be used by your service, and can't be shared with other unrelated services.

This is made possible by generating a VAPID key pair to represent your server with. At time of registration, the public key is shared with the browser, and the subscription that is returned is locked to this key. When sending a push message, the private key is used to identify your application server to the push service so that it knows who you are before forwarding messages to subscribers.

> [!CAUTION]
> It is important to note that you should strive to use the same key for as long as possible for a given subscriber — you won't be able to send messages to existing subscribers if you ever regenerate this key, so keep it secure!

</details>

<details>
<summary><strong>Push Service</strong></summary>

A **Push Service** is run by browsers to coordinate delivery of messages to subscribers on your behalf.

</details>


### Generating Keys

Before integrating WebPush into your server, you must generate one time VAPID keys to identify your server to push services with. To help we this, we provide `vapid-key-generator`, which you can install and use as needed:
```zsh
% git clone https://github.com/mochidev/swift-webpush.git
% cd swift-webpush/vapid-key-generator
% swift package experimental-install
```

To uninstall the generator:
```zsh
% swift package experimental-uninstall vapid-key-generator
```

To update the generator, uninstall it and re-install it after pulling from main:
```zsh
% swift package experimental-uninstall vapid-key-generator
% swift package experimental-install
```

Once installed, a new configuration can be generated as needed. Here, we generate a configuration with `https://example.com` as our support URL for push service administrators to use to contact us when issues occur:
```
% ~/.swiftpm/bin/vapid-key-generator https://example.com
VAPID.Configuration: {"contactInformation":"https://example.com","expirationDuration":79200,"primaryKey":"6PSSAJiMj7uOvtE4ymNo5GWcZbT226c5KlV6c+8fx5g=","validityDuration":72000}


Example Usage:
    // TODO: Load this data from .env or from file system
    let configurationData = Data(#" {"contactInformation":"https://example.com","expirationDuration":79200,"primaryKey":"6PSSAJiMj7uOvtE4ymNo5GWcZbT226c5KlV6c+8fx5g=","validityDuration":72000} "#.utf8)
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

During the setup stage of your application server, decode the VAPID configuration you created above and initialize a `WebPushManager` with it:

```swift
import WebPush

...

guard
    let rawVAPIDConfiguration = ProcessInfo.processInfo.environment["VAPID-CONFIG"],
    let vapidConfiguration = try? JSONDecoder().decode(VAPID.Configuration.self, from: Data(rawVAPIDConfiguration.utf8))
else { fatalError("VAPID keys are unavailable, please generate one and add it to the environment.") }

let manager = WebPushManager(
    vapidConfiguration: vapidConfiguration,
    backgroundActivityLogger: logger
    /// If you customized the event loop group your app uses, you can set it here:
    // eventLoopGroupProvider: .shared(app.eventLoopGroup)
)

try await ServiceGroup(
    services: [
        /// Your other services here
        manager
    ],
    gracefulShutdownSignals: [.sigint],
    logger: logger
).run()
```

If you are not yet using [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle), you can skip adding it to the service group, and it'll shut down on deinit instead. This however may be too late to finish sending over all in-flight messages, so prefer to use a ServiceGroup for all your services if you can.

You'll also want to serve a `serviceWorker.mjs` file at the root of your server (it can be anywhere, but there are scoping restrictions that are simplified by serving it at the root) to handle incoming notifications:

```js
self.addEventListener('push', function(event) {
    const data = event.data?.json() ?? {};
    event.waitUntil((async () => {
        /// Try parsing the data, otherwise use fallback content. DO NOT skip sending the notification, as you must display one for every push message that is received or your subscription will be dropped.
        let title = data?.title ?? "Your App Name";
        const body = data?.body ?? "New Content Available!";
        
        await self.registration.showNotification(title, { 
            body, 
            icon: "/notification-icon.png", /// Only some browsers support this.
            data
        });
    })());
});
```

> [!NOTE]
> `.mjs` here allows your code to import other js modules as needed. If you are not using Vapor, please make sure your server uses the correct mime type for this file extension.


### Registering Subscribers

To register a subscriber, you'll need backend code to provide your VAPID key, and frontend code to ask the browser for a subscription on behalf of the user.

On the backend (we are assuming Vapor here), register a route that returns your VAPID public key:

```swift
import WebPush

...

/// Listen somewhere for a VAPID key request. This path can be anything you want, and should be available to all parties you with to serve push messages to.
app.get("vapidKey", use: loadVapidKey)

...

/// A wrapper for the VAPID key that Vapor can encode.
struct WebPushOptions: Codable, Content, Hashable, Sendable {
    static let defaultContentType = HTTPMediaType(type: "application", subType: "webpush-options+json")

    var vapid: VAPID.Key.ID
}

/// The route handler, usually part of a route controller.
@Sendable func loadVapidKey(request: Request) async throws -> WebPushOptions {
    WebPushOptions(vapid: manager.nextVAPIDKeyID)
}
```

Also register a route for persisting `Subscriber`'s:

```swift
import WebPush

...

/// Listen somewhere for new registrations. This path can be anything you want, and should be available to all parties you with to serve push messages to.
app.get("registerSubscription", use: registerSubscription)

...

/// A custom type for communicating the status of your subscription. Fill this out with any options you'd like to communicate back to the user.
struct SubscriptionStatus: Codable, Content, Hashable, Sendable {
    var subscribed = true
}

/// The route handler, usually part of a route controller.
@Sendable func registerSubscription(request: Request) async throws -> SubscriptionStatus {
    let subscriptionRequest = try request.content.decode(Subscriber.self, as: .jsonAPI)
    
    // TODO: Persist subscriptionRequest!
    
    return SubscriptionStatus()
}
```

> [!NOTE]
> `WebPushManager` (`manager` here) is fully sendable, and should be shared with your controllers using dependency injection. This allows you to fully test your application server by relying on the provided `WebPushTesting` library in your unit tests to mock keys, verify delivery, and simulate errors.

On the frontend, register your service worker, fetch your vapid key, and subscribe on behalf of the user:

```js
const serviceRegistration = await navigator.serviceWorker?.register("/serviceWorker.mjs", { type: "module" });
let subscription = await registration?.pushManager?.getSubscription();

/// Wait for the user to interact with the page to request a subscription.
document.getElementById("notificationsSwitch").addEventListener("click", async ({ currentTarget }) => {
    try {
        /// If we couldn't load a subscription, now's the time to ask for one.
        if (!subscription) {
            const applicationServerKey = await loadVAPIDKey();
            subscription = await serviceRegistration.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey,
            });
        }
        
        /// It is safe to re-register the same subscription.
        const subscriptionStatusResponse = await registerSubscription(subscription);
        
        /// Do something with your registration. Some may use it to store notification settings and display those back to the user.
        ...
    } catch (error) {
        /// Tell the user something went wrong here.
        console.error(error);
    }
}
});

...

async function loadVAPIDKey() {
    /// Make sure this is the same route used above.
    const httpResponse = await fetch(`/vapidKey`);

    const webPushOptions = await httpResponse.json();
    if (httpResponse.status != 200) throw new Error(webPushOptions.reason);

    return webPushOptions.vapid;
}

export async function registerSubscription(subscription) {
    /// Make sure this is the same route used above.
    const subscriptionStatusResponse = await fetch(`/registerSubscription`, {
        method: "POST",
        body: {
            ...subscription.toJSON(),
            /// It is good practice to provide the applicationServerKey back here so we can track which one was used if multiple were provided during configuration.
            applicationServerKey: subscription.options.applicationServerKey,
        }
    });
    
    /// Do something with your registration. Some may use it to store notification settings and display those back to the user.
    ...
}
```


### Sending Messages

To send a message, call one of the `send()` methods on `WebPushManager` with a `Subscriber`:

```swift
import WebPush

...

do {
    try await manager.send(
        json: ["title": "Test Notification", "body": "Hello, World!"
        /// If sent from a request, pass the request's logger here to maintain its metadata.
        // logger: request.logger
    )
} catch BadSubscriberError() {
    /// The subscription is no longer valid and should be removed.
} catch MessageTooLargeError() {
    /// The message was too long and should be shortened.
} catch let error as HTTPError {
    /// The push service ran into trouble. error.response may help here.
} catch {
    /// An unknown error occurred.
}
```

Your service worker will receive this message, decode it, and present it to the user.

> [!NOTE]
> Although the spec supports it, most browsers do not support silent notifications, and will drop a subscription if they are used.


### Testing

The `WebPushTesting` module can be used to obtain a mocked `WebPushManager` instance that allows you to capture all messages that are sent out, or throw your own errors to validate your code functions appropriately.

> [!IMPORTANT]
> Only import `WebPushTesting` in your testing targets.

```swift
import Testing
import WebPushTesting

@Test func sendSuccessfulNotifications() async throws {
    try await confirmation { requestWasMade in
        let mockedManager = WebPushManager.makeMockedManager { message, subscriber, topic, expiration, urgency in
            #expect(message.string == "hello")
            #expect(subscriber.endpoint.absoluteString == "https://example.com/expectedSubscriber")
            #expect(subscriber.vapidKeyID == .mockedKeyID1)
            #expect(topic == nil)
            #expect(expiration == .recommendedMaximum)
            #expect(urgency == .high)
            requestWasMade()
        }
        
        let myController = MyController(pushManager: mockedManager)
        try await myController.sendNotifications()
    }
}

@Test func catchBadSubscriptions() async throws {
    /// Mocked managers accept multiple handlers, and will cycle through them each time a push message is sent:
    let mockedManager = WebPushManager.makeMockedManager(messageHandlers:
        { _, _, _, _, _ in throw BadSubscriberError() },
        { _, _, _, _, _ in },
        { _, _, _, _, _ in throw BadSubscriberError() },
    )
    
    let myController = MyController(pushManager: mockedManager)
    #expect(myController.subscribers.count == 3)
    try await myController.sendNotifications()
    #expect(myController.subscribers.count == 1)
}
```

## Specifications

- [RFC 6454 — The Web Origin Concept](https://datatracker.ietf.org/doc/html/rfc6454)
- [RFC 7515 — JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515)
- [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 8030 — Generic Event Delivery Using HTTP Push](https://datatracker.ietf.org/doc/html/rfc8030)
- [RFC 8188 — Encrypted Content-Encoding for HTTP](https://datatracker.ietf.org/doc/html/rfc8188)
- [RFC 8291 — Message Encryption for Web Push](https://datatracker.ietf.org/doc/html/rfc8291)
- [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push](https://datatracker.ietf.org/doc/html/rfc8292)


- [Push API Working Draft](https://www.w3.org/TR/push-api/)


## Other Resources

- [Apple Developer — Sending web push notifications in web apps and browsers](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers)
- [WWDC22 — Meet Web Push for Safari](https://developer.apple.com/videos/play/wwdc2022/10098/)
- [WebKit — Meet Web Push](https://webkit.org/blog/12945/meet-web-push/)
- [WebKit — Web Push for Web Apps on iOS and iPadOS](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)
- [MDN — Push API](https://developer.mozilla.org/en-US/docs/Web/API/Push_API)
- [MDN — Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [web.dev — The Web Push Protocol](https://web.dev/articles/push-notifications-web-push-protocol)
- [Sample Code — ServiceWorker Cookbook](https://github.com/mdn/serviceworker-cookbook/tree/master/push-simple)
- [Web Push: Data Encryption Test Page](https://mozilla-services.github.io/WebPushDataTestPage/)

## Contributing

Contribution is welcome! Please take a look at the issues already available, or start a new discussion to propose a new feature. Although guarantees can't be made regarding feature requests, PRs that fit within the goals of the project and that have been discussed beforehand are more than welcome!

Please make sure that all submissions have clean commit histories, are well documented, and thoroughly tested. **Please rebase your PR** before submission rather than merge in `main`. Linear histories are required, so merge commits in PRs will not be accepted.

## Support

To support this project, consider following [@dimitribouniol](https://mastodon.social/@dimitribouniol) on Mastodon, listening to Spencer and Dimitri on [Code Completion](https://mastodon.social/@codecompletion), or downloading Linh and Dimitri's apps:
- [Not Phở](https://notpho.app/)
- [Jiiiii](https://jiiiii.moe/)

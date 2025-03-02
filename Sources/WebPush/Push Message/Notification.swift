//
//  Notification.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2025-02-26.
//  Copyright © 2024-25 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - Notification

extension PushMessage {
    /// A Declarative Push Notification.
    ///
    /// Declarative push notifications don't require a service worker to be running for a notification to be displayed, simplifying deployment on supported browsers.
    ///
    /// - Important: As of 2025-02-28, declarative notifications are experimental and supported only in [Safari 18.4 Beta](https://developer.apple.com/documentation/safari-release-notes/safari-18_4-release-notes).
    ///
    /// - Note: Support for Declarative Push Notifications is currently experimental in [WebKit and Safari betas](https://developer.apple.com/documentation/safari-release-notes/safari-18_4-release-notes) only, but falls back gracefully to a service worker implementation if unsupported. It is therefore required that you still deploy and register a service worker for push notifications to be successfully delivered to most subscribers.
    public struct Notification<Contents: Sendable & Encodable>: Sendable {
        /// The kind of notification to deliver.
        ///
        /// Defaults to ``PushMessage/NotificationKind/declarative``.
        ///
        /// - Note: This property is encoded as `web_push` in JSON.
        ///
        /// - Important: As of 2025-02-28, declarative notifications are experimental and supported only in [Safari 18.4 Beta](https://developer.apple.com/documentation/safari-release-notes/safari-18_4-release-notes).
        ///
        /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
        public var kind: NotificationKind
        
        
        /// The destination URL that should be opened when the user interacts with the notification.
        ///
        /// - Note: This property is encoded as `navigate` in JSON.
        ///
        /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
        /// - SeeAlso: [WHATWG Notifications API — PR #213 — §2. Notifications](https://whatpr.org/notifications/213.html#notification-navigation-url)
        /// - SeeAlso: [WHATWG Notifications API — PR #213 — §2.7. Activating a notification](https://whatpr.org/notifications/213.html#activating-a-notification)
        public var destination: URL
        
        /// The notification's title.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `title` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/title)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#concept-title)
        public var title: String
        
        /// The notification's body text.
        ///
        /// Defaults to `nil`.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `body` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/body)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#body)
        public var body: String?
        
        /// The image to be displayed in the notification.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `image` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/image)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#image-resource)
        /// - SeeAlso: [WHATWG Notifications API — §2.5. Resources](https://notifications.spec.whatwg.org/#resources)
        public var image: URL?
        
        /// The actions available on the notification for a user to interact with.
        ///
        /// Defaults to an empty array, which means the notification will only support its default ``destination``.
        ///
        /// - Important: Different browser implementations handle provided actions differently — some may limit their number or omit them completely. You are encouraged to provide an interface to handle all these options as a fallback for such scenarios.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `actions` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/actions)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#actions)
        public var actions: [NotificationAction]
        
        
        /// The date and time that should be attached to a notification.
        ///
        /// Defaults to the time the notification was sent. However, a time in the past may be used for an event that already happened, or a time in the future may be used for an event that is planned but did not start yet.
        ///
        /// - Important: Timezone data is not communicated with the standard, and the subscriber's default timezone will always be used instead.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `timestamp` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/timestamp)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#timestamp)
        public var timestamp: Date?
        
        /// Optional data to associate with a notification for when a service worker processes it.
        ///
        /// Associating data with a notification does not guarantee a service worker will be available to process it; the ``isMutable`` preference must still be set to true. If you need to guarantee a message that contains data is processed on the client side by a service worker, you can instead choose to send a non-declarative message, but note that the notification will only be delivered if a service worker is still running on the user's device.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `data` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/data)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#data)
        public var data: Contents?
        
        
        /// The badge count to display on a PWA's app icon.
        ///
        /// Defaults to `nil`, indicating no badge should be shown.
        ///
        /// - Note: This property is encoded as `app_badge` in JSON.
        ///
        /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
        public var appBadgeCount: Int?
        
        /// A preference indicating if a notification can be mutated by a service worker running on the subscriber's device.
        ///
        /// Defaults to `false`. Setting this to `true` requires a service worker be registered to handle capturing the notification in order to mutate it before presentation. Note that the service worker may be skipped if it is not running, and the notification will be presented as is.
        ///
        /// - Note: This property is encoded as `mutable` in JSON.
        ///
        /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
        public var isMutable: Bool
        
        /// Additional options and configuration for a notification.
        ///
        /// Defaults to an empty ``PushMessage/NotificationOptions`` configuration of options.
        ///
        /// - SeeAlso: [MDN Notifications — Notification](https://developer.mozilla.org/en-US/docs/Web/API/Notification)
        public var options: NotificationOptions
        
        
        /// Initialize a new Declarative Push Notification.
        ///
        /// - Important: The entire notification must fit within ``WebPushManager/maximumMessageSize`` once encoded, or sending the notification will fail. Keep this in mind when specifying data to be sent along with the notification.
        ///
        /// - Parameters:
        ///   - kind: The kind of notification to send. Defaults to ``PushMessage/NotificationKind/declarative``.
        ///   - destination: The destination URL that should be opened when the user interacts with the notification.
        ///   - title: The notification's title text.
        ///   - body: The notification's body text. Defaults to `nil`.
        ///   - image: A URL for the image to display in a notification. Defaults to `nil`.
        ///   - actions: A list of actions to display alongside the notification. Defaults to an empty array.
        ///   - timestamp: The timestamp to attach to the notification. Defaults to `.now`.
        ///   - data: Optional data to associate with the notification for when a service worker is used. Defaults to `nil`.
        ///   - appBadgeCount: The badge numeral to use for a PWA's app icon. Defaults to `nil`.
        ///   - isMutable: A preference indicating the notification should first be processed by a service worker. Defaults to `false`.
        ///   - options: Notification options to use for additional configuration. See ``PushMessage/NotificationOptions``.
        public init(
            kind: NotificationKind = .declarative,
            destination: URL,
            title: String,
            body: String? = nil,
            image: URL? = nil,
            actions: [NotificationAction] = [],
            timestamp: Date? = .now,
            data: Contents?,
            appBadgeCount: Int? = nil,
            isMutable: Bool = false,
            options: NotificationOptions = NotificationOptions()
        ) {
            self.kind = kind
            self.destination = destination
            self.title = title
            self.body = body
            self.image = image
            self.actions = actions
            self.timestamp = timestamp
            self.data = data
            self.appBadgeCount = appBadgeCount
            self.isMutable = isMutable
            self.options = options
        }
    }
}

extension PushMessage.Notification where Contents == Never {
    /// Initialize a new Declarative Push Notification.
    ///
    /// - Important: The entire notification must fit within ``WebPushManager/maximumMessageSize`` once encoded, or sending the notification will fail. Keep this in mind when specifying data to be sent along with the notification.
    /// 
    /// - Parameters:
    ///   - kind: The kind of notification to send. Defaults to ``PushMessage/NotificationKind/declarative``.
    ///   - destination: The destination URL that should be opened when the user interacts with the notification.
    ///   - title: The notification's title text.
    ///   - body: The notification's body text. Defaults to `nil`.
    ///   - image: A URL for the image to display in a notification. Defaults to `nil`.
    ///   - actions: A list of actions to display alongside the notification. Defaults to an empty array.
    ///   - timestamp: The timestamp to attach to the notification. Defaults to `.now`.
    ///   - data: Optional data to associate with the notification for when a service worker is used. Defaults to `nil`.
    ///   - appBadge: The badge numeral to use for a PWA's app icon. Defaults to `nil`.
    ///   - isMutable: A preference indicating the notification should first be processed by a service worker. Defaults to `false`.
    ///   - options: Notification options to use for additional configuration. See ``PushMessage/NotificationOptions``.
    public init(
        kind: PushMessage.NotificationKind = .declarative,
        destination: URL,
        title: String,
        body: String? = nil,
        image: URL? = nil,
        actions: [PushMessage.NotificationAction] = [],
        timestamp: Date? = .now,
        appBadgeCount: Int? = nil,
        isMutable: Bool = false,
        options: PushMessage.NotificationOptions = PushMessage.NotificationOptions()
    ) where Contents == Never {
        self.kind = kind
        self.destination = destination
        self.title = title
        self.body = body
        self.image = image
        self.actions = actions
        self.timestamp = timestamp
        self.data = nil
        self.appBadgeCount = appBadgeCount
        self.isMutable = isMutable
        self.options = options
    }
}

extension PushMessage {
    /// A declarative push notification with no data associated with it.
    ///
    /// This should only be used when decoding a notification you know has no custom ``PushMessage/Notification/data`` associated with it, though decoding will fail if it does.
    public typealias SimpleNotification = Notification<Never>
}

extension PushMessage.Notification: Encodable {
    /// The keys used when encoding a top-level ``PushMessage/Notification``.
    ///
    /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
    public enum MessageCodingKeys: String, CodingKey {
        case webPushIdentifier = "web_push"
        case notification
        case appBadgeCount = "app_badge"
        case isMutable = "mutable"
    }
    
    /// The keys used when encoding a ``PushMessage/Notification`` as a ``PushMessage/Notification/MessageCodingKeys/notification``.
    ///
    /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
    public enum NotificationCodingKeys: String, CodingKey {
        case title
        case direction = "dir"
        case language = "lang"
        case body
        case destination = "navigate"
        case tag
        case image
        case icon
        case badgeIcon = "badge"
        case vibrate
        case timestamp
        case shouldRenotify = "renotify"
        case isSilent = "silent"
        case requiresInteraction = "require_interaction"
        case data
        case actions
    }
    
    public func encode(to encoder: any Encoder) throws {
        var messageContainer = encoder.container(keyedBy: MessageCodingKeys.self)
        
        switch kind {
        case .declarative:
            try messageContainer.encode(PushMessage.declarativePushMessageIdentifier, forKey: .webPushIdentifier)
        case .legacy: break
        }
        
        var notificationContainer = messageContainer.nestedContainer(keyedBy: NotificationCodingKeys.self, forKey: .notification)
        try notificationContainer.encode(title, forKey: .title)
        if options.direction != .auto { try notificationContainer.encode(options.direction, forKey: .direction) }
        try notificationContainer.encodeIfPresent(options.language, forKey: .language)
        try notificationContainer.encodeIfPresent(body, forKey: .body)
        try notificationContainer.encode(destination, forKey: .destination)
        try notificationContainer.encodeIfPresent(options.tag, forKey: .tag)
        try notificationContainer.encodeIfPresent(image, forKey: .image)
        try notificationContainer.encodeIfPresent(options.icon, forKey: .icon)
        try notificationContainer.encodeIfPresent(options.badgeIcon, forKey: .badgeIcon)
        if !options.vibrate.isEmpty { try notificationContainer.encode(options.vibrate, forKey: .vibrate) }
        try notificationContainer.encodeIfPresent(timestamp.map { Int($0.timeIntervalSince1970*1000) }, forKey: .timestamp)
        if options.shouldRenotify { try notificationContainer.encode(true, forKey: .shouldRenotify) }
        if options.isSilent { try notificationContainer.encode(true, forKey: .isSilent) }
        if options.requiresInteraction { try notificationContainer.encode(true, forKey: .requiresInteraction) }
        try notificationContainer.encodeIfPresent(data, forKey: .data)
        if !actions.isEmpty { try notificationContainer.encode(actions, forKey: .actions) }
        
        try messageContainer.encodeIfPresent(appBadgeCount, forKey: .appBadgeCount)
        if isMutable { try messageContainer.encode(isMutable, forKey: .isMutable) }
    }
}

extension PushMessage.Notification: Decodable where Contents: Decodable {
    public init(from decoder: any Decoder) throws {
        let messageContainer = try decoder.container(keyedBy: MessageCodingKeys.self)
        
        self.kind = if let webPushIdentifier = try messageContainer.decodeIfPresent(Int.self, forKey: .webPushIdentifier),
           webPushIdentifier == PushMessage.declarativePushMessageIdentifier
        {
            .declarative
        } else {
            .legacy
        }
        
        let notificationContainer = try messageContainer.nestedContainer(keyedBy: NotificationCodingKeys.self, forKey: .notification)
        self.title = try notificationContainer.decode(String.self, forKey: .title)
        self.body = try notificationContainer.decodeIfPresent(String.self, forKey: .body)
        self.destination = try notificationContainer.decode(URL.self, forKey: .destination)
        self.image = try notificationContainer.decodeIfPresent(URL.self, forKey: .image)
        self.timestamp = try notificationContainer.decodeIfPresent(Double.self, forKey: .timestamp).map { Date(timeIntervalSince1970: $0/1000) }
        self.data = try notificationContainer.decodeIfPresent(Contents.self, forKey: .data)
        self.actions = try notificationContainer.decodeIfPresent([PushMessage.NotificationAction].self, forKey: .actions) ?? []
        self.options = PushMessage.NotificationOptions(
            direction: try notificationContainer.decodeIfPresent(PushMessage.NotificationOptions.Direction.self, forKey: .direction) ?? .auto,
            language: try notificationContainer.decodeIfPresent(String.self, forKey: .language),
            tag: try notificationContainer.decodeIfPresent(String.self, forKey: .tag),
            icon: try notificationContainer.decodeIfPresent(URL.self, forKey: .icon),
            badgeIcon: try notificationContainer.decodeIfPresent(URL.self, forKey: .badgeIcon),
            vibrate: try notificationContainer.decodeIfPresent([Int].self, forKey: .vibrate) ?? [],
            shouldRenotify: try notificationContainer.decodeIfPresent(Bool.self, forKey: .shouldRenotify) ?? false,
            isSilent: try notificationContainer.decodeIfPresent(Bool.self, forKey: .isSilent) ?? false,
            requiresInteraction: try notificationContainer.decodeIfPresent(Bool.self, forKey: .requiresInteraction) ?? false
        )
        
        self.appBadgeCount = try messageContainer.decodeIfPresent(Int.self, forKey: .appBadgeCount)
        self.isMutable = try messageContainer.decodeIfPresent(Bool.self, forKey: .isMutable) ?? false
    }
}

extension PushMessage.Notification: Equatable where Contents: Equatable {}
extension PushMessage.Notification: Hashable where Contents: Hashable {}

// MARK: - NotificationKind

extension PushMessage {
    /// The type of notification to encode.
    public enum NotificationKind: Hashable, Sendable {
        /// A declarative notification that a browser can display independently without a service worker.
        ///
        /// This sets ``PushMessage/Notification/MessageCodingKeys/webPushIdentifier`` key (`web_push`) to ``PushMessage/declarativePushMessageIdentifier`` (`8030`).
        ///
        /// - Important: As of 2025-02-28, declarative notifications are experimental and supported only in [Safari 18.4 Beta](https://developer.apple.com/documentation/safari-release-notes/safari-18_4-release-notes).
        case declarative
        
        /// A legacy push message that a service worker must transform before displaying manually.
        ///
        /// This omits the ``PushMessage/Notification/MessageCodingKeys/webPushIdentifier`` key (`web_push`).
        case legacy
    }
}

// MARK: - NotificationOptions

extension PushMessage {
    /// Additional options and configuration to use when presenting a notification.
    ///
    /// - SeeAlso: [MDN Notifications — Notification](https://developer.mozilla.org/en-US/docs/Web/API/Notification)
    public struct NotificationOptions: Hashable, Sendable {
        /// The language direction for the notification's title, body, action titles, and order of actions.
        ///
        /// Defaults to ``Direction-swift.enum/auto``.
        ///
        /// - Note: This property is encoded as `dir` in JSON.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `dir` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/dir)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#concept-direction)
        /// - SeeAlso: [WHATWG Notifications API — §2.3. Direction](https://notifications.spec.whatwg.org/#direction)
        public var direction: Direction
        
        /// The notification's language.
        ///
        /// - Note: This property is encoded as `lang` in JSON.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `lang` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/lang)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#concept-language)
        /// - SeeAlso: [WHATWG Notifications API — §2.4. Language](https://notifications.spec.whatwg.org/#language)
        public var language: String?
        
        
        /// A tag to use to de-duplicate or replace notifications before they are presented to the user.
        ///
        /// Defaults to `nil`, indicating all notifications should be presented in isolation from one another.
        ///
        /// - Note: This is similar to providing a ``Topic`` when submitting the message, however the tag is used _after_ the message is delivered to the browser, while the topic is used before the browser connects to the push service to retrieve notifications for a subscriber.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `tag` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/tag)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#tag)
        /// - SeeAlso: [WHATWG Notifications API — §3.5.3. Using the tag member for multiple instances](https://notifications.spec.whatwg.org/#using-the-tag-member-for-a-single-instance)
        public var tag: String?
        
        
        /// The icon to be displayed alongside the notification.
        ///
        /// If unspecified, the site's icon will be used instead.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `icon` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/icon)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#icon-resource)
        /// - SeeAlso: [WHATWG Notifications API — §2.5. Resources](https://notifications.spec.whatwg.org/#resources)
        public var icon: URL?
        
        /// The badge icon image to represent the notification when there is not enough space to display the notification itself such as for example, the Android Notification Bar.
        ///
        /// Defaults to `nil`, indicating the site's icon should be used.
        ///
        /// - Note: This property is encoded as `badge` in JSON.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `badge` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/badge)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#badge-resource)
        /// - SeeAlso: [WHATWG Notifications API — §2.5. Resources](https://notifications.spec.whatwg.org/#resources)
        public var badgeIcon: URL?
        
        
        /// The vibration pattern to use when alerting the user.
        ///
        /// Defaults to an empty array, indicating the notification should follow subscriber preferences.
        ///
        /// The sequence of numbers represents the amount of time in milliseconds to alternatively vibrate and pause. For instance, `[200]` will vibrate for 0.2s, while `[200, 100, 200]` will vibrate for 0.2s, pause for 0.1s, and vibrate again for 0.2s.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `vibrate` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/vibrate)
        /// - SeeAlso: [MDN Vibration API](https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#vibration-pattern)
        /// - SeeAlso: [WHATWG Notifications API — §2.9. Alerting the end user](https://notifications.spec.whatwg.org/#alerting-the-user)
        public var vibrate: [Int]
        
        
        /// A preference indicating if the user should be alerted again after the initial notification was presented when another notification with the same ``tag`` is sent.
        ///
        /// Defaults to `false`, indicating the second notification should be ignored.
        ///
        /// - Note: This property is encoded as `renotify` in JSON.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `renotify` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/renotify)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#renotify-preference-flag)
        /// - SeeAlso: [WHATWG Notifications API — §2.6. Showing a notification](https://notifications.spec.whatwg.org/#showing-a-notification)
        public var shouldRenotify: Bool
        
        /// A preference indicating if the notification should be presented without sounds or vibrations.
        ///
        /// Defaults to `false`, indicating the notification should follow subscriber preferences.
        ///
        /// - Note: This property is encoded as `silent` in JSON.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `silent` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/silent)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#silent-preference-flag)
        public var isSilent: Bool
        
        /// For devices with sufficiently large screens (ie. a laptop or desktop), a preference indicating if the notification should stay on screen until the user interacts with it rather than dismiss automatically.
        ///
        /// Defaults to `false`, indicating the notification should follow subscriber preferences.
        ///
        /// - Note: This property is encoded as `requires_interaction` in JSON.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `requireInteraction` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/requireInteraction)
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#require-interaction-preference-flag)
        public var requiresInteraction: Bool
        
        
        /// Initialize notification options.
        /// - Parameters:
        ///   - direction: The language direction for the notification. Defaults to ``Direction-swift.enum/auto``.
        ///   - language: The language tag for the notification. Defaults to `nil`.
        ///   - tag: The tag to deduplicate or replace presentation of the notification. Defaults to `nil`.
        ///   - icon: A URL for the icon the notification should use. Defaults to `nil`.
        ///   - badgeIcon: A URL for the badge icon the notification should use. Defaults to `nil`.
        ///   - vibrate: A vibration pattern the notification should use. Defaults to `nil`.
        ///   - shouldRenotify: A preference indicating if the notification with the same tag should be re-presented. Defaults to `false`.
        ///   - isSilent: A preference indicating if the notification should be presented without sound or vibrations. Defaults to `false`.
        ///   - requiresInteraction: A preference indicating if the notification stays on screen until the user interacts with it. Defaults to `false`.
        public init(
            direction: Direction = .auto,
            language: String? = nil,
            tag: String? = nil,
            icon: URL? = nil,
            badgeIcon: URL? = nil,
            vibrate: [Int] = [],
            shouldRenotify: Bool = false,
            isSilent: Bool = false,
            requiresInteraction: Bool = false
        ) {
            self.direction = direction
            self.language = language
            self.tag = tag
            self.icon = icon
            self.badgeIcon = badgeIcon
            self.vibrate = vibrate
            self.shouldRenotify = shouldRenotify
            self.isSilent = isSilent
            self.requiresInteraction = requiresInteraction
        }
    }
}

// MARK: - NotificationOptions.Direction

extension PushMessage.NotificationOptions {
    /// The language direction for the notification's title, body, action titles, and order of actions.
    ///
    /// - SeeAlso: [MDN Notifications — Notification: `dir` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/dir)
    /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#concept-direction)
    /// - SeeAlso: [WHATWG Notifications API — §2.3. Direction](https://notifications.spec.whatwg.org/#direction)
    public enum Direction: String, Hashable, Codable, Sendable {
        /// Use the browser's language defaults.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `dir` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/dir#auto)
        case auto
        
        /// The notification should be presented left-to-right.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `dir` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/dir#ltr)
        case leftToRight = "ltr"
        
        /// The notification should be presented right-to-left.
        ///
        /// - SeeAlso: [MDN Notifications — Notification: `dir` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/dir#rtl)
        case rightToLeft = "rtf"
    }
}

// MARK: - NotificationAction

extension PushMessage {
    /// An associated action for a notification when it is displayed to the user.
    ///
    /// - Note: Not all browsers support displaying actions.
    ///
    /// - SeeAlso: [MDN Notifications — Notification: `actions` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/actions)
    /// - SeeAlso: [WHATWG Notifications API — §3. API — `NotificationAction`](https://notifications.spec.whatwg.org/#dictdef-notificationaction)
    public struct NotificationAction: Hashable, Codable, Sendable, Identifiable {
        /// The action's identifier.
        ///
        /// This can be used when handling an action from a service worker directly.
        ///
        /// - Note: This property is encoded as `action` in JSON.
        ///
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#action-name)
        /// - SeeAlso: [MDN Notifications — Notification: `actions` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/actions#action)
        /// - SeeAlso: [WHATWG Notifications API — §3.5.2. Using actions from a service worker](https://notifications.spec.whatwg.org/#using-actions)
        public var id: String
        
        /// The action button's label.
        ///
        /// - Note: This property is encoded as `title` in JSON.
        ///
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#action-title)
        /// - SeeAlso: [MDN Notifications — Notification: `actions` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/actions#title)
        public var label: String
        
        /// The destination that will be opened when the action's button is pressed.
        ///
        /// - Note: This property is encoded as `navigation` in JSON.
        ///
        /// - SeeAlso: [WHATWG Notifications API — PR #213 — §2. Notifications](https://whatpr.org/notifications/213.html#notification-action-navigation-url)
        /// - SeeAlso: [WHATWG Notifications API — PR #213 — §2.7. Activating a notification](https://whatpr.org/notifications/213.html#activating-a-notification)
        public var destination: URL
        
        /// The URL of an icon to display with the action.
        ///
        /// - SeeAlso: [WHATWG Notifications API — §2. Notifications](https://notifications.spec.whatwg.org/#action-icon)
        /// - SeeAlso: [MDN Notifications — Notification: `actions` property](https://developer.mozilla.org/en-US/docs/Web/API/Notification/actions#icon)
        public var icon: URL?
        
        /// The keys used when encoding ``PushMessage/NotificationAction``.
        public enum CodingKeys: String, CodingKey {
            case id = "action"
            case label = "title"
            case destination = "navigate"
            case icon
        }
    }
}

// MARK: - Constants

extension PushMessage {
    /// An integer that must be `8030`. Used to disambiguate a declarative push message from other JSON documents.
    ///
    /// - SeeAlso: [Push API Editor's Draft — §3.3.1. Members](https://raw.githubusercontent.com/w3c/push-api/refs/heads/declarative-push/index.html#members)
    public static let declarativePushMessageIdentifier = 8030
}

// MARK: - Additional Conformances

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
extension Never: @retroactive Codable {
    /// A default implementation for Never for macOS 13, since official support was added in macOS 14.
    ///
    /// - SeeAlso: https://github.com/swiftlang/swift/blob/af3e7e765549c0397288e60983c96d81639287ed/stdlib/public/core/Policy.swift#L81-L86
    public func encode(to encoder: any Encoder) throws {}
    
    /// A default implementation for Never for macOS 13, since official support was added in macOS 14.
    ///
    /// - SeeAlso: https://github.com/swiftlang/swift/blob/af3e7e765549c0397288e60983c96d81639287ed/stdlib/public/core/Policy.swift#L88-L98
    public init(from decoder: any Decoder) throws {
        let context = DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Unable to decode an instance of Never."
        )
        throw DecodingError.typeMismatch(Never.self, context)
    }
}
#endif

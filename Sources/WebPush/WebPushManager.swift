//
//  WebPushManager.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
@preconcurrency import Crypto
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOHTTP1
import Logging
import NIOCore
import NIOPosix
import ServiceLifecycle

/// A manager for sending push messages to subscribers.
///
/// You should instantiate and keep a reference to a single manager, passing a reference as a dependency to requests and other controllers that need to send messages. This is because the manager has an internal cache for managing connections to push services.
///
/// The manager should be installed as a service to wait for any in-flight messages to be sent before your application server shuts down.
public actor WebPushManager: Sendable {
    /// The VAPID configuration used when configuring the manager.
    public nonisolated let vapidConfiguration: VAPID.Configuration
    
    /// The network configuration used when configuring the manager.
    public nonisolated let networkConfiguration: NetworkConfiguration
    
    /// The maximum encrypted payload size guaranteed by the spec.
    ///
    /// Currently the spec guarantees up to 4,096 encrypted bytes will always be successfull.
    ///
    /// - Note: _Some_, but not all, push services allow an effective encrypted message size that is larger than this, as they misinterpreted the 4096 maximum payload size as the plaintext maximum size, and support the larger size to this day. This library will however warn if this threshold is surpassed and attempt sending the message anyways — it is up to the caller to make sure messages over this size are not regularly attempted, and for fallback mechanisms to be put in place should push result in an error.
    public static let maximumEncryptedPayloadSize = 4096
    
    /// The maximum message size allowed.
    ///
    /// This is currently set to 3,993 plaintext bytes. See the discussion for ``maximumEncryptedPayloadSize`` for more information.
    public static let maximumMessageSize = maximumEncryptedPayloadSize - 103
    
    /// The encoder used when serializing JSON messages.
    public static let messageEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.withoutEscapingSlashes]
        
        return encoder
    }()
    
    /// The internal logger to use when reporting misconfiguration and background activity.
    nonisolated let backgroundActivityLogger: Logger
    
    /// The internal executor to use when delivering messages.
    var executor: Executor
    
    /// An internal flag indicating if a manager was shutdown already.
    var didShutdown = false
    
    /// An internal flag indicating if a manager should skipShutting down its client.
    var skipClientShutdown = false
    
    /// An internal lookup of keys as provided by the VAPID configuration.
    let vapidKeyLookup: [VAPID.Key.ID : VAPID.Key]
    
    /// An internal cache of `Authorization` header values for a combination of endpoint origin and VAPID key ID.
    /// - SeeAlso: ``loadCurrentVAPIDAuthorizationHeader(endpoint:signingKey:)``
    var vapidAuthorizationCache: [String : (authorization: String, validUntil: Date)] = [:]
    
    /// Initialize a manager with a VAPID configuration.
    /// 
    /// - Note: On debug builds, this initializer will assert if VAPID authorization header expiration times are inconsistently set.
    /// - Parameters:
    ///   - vapidConfiguration: The VAPID configuration to use when identifying the application server.
    ///   - networkConfiguration: The network configuration used when configuring the manager.
    ///   - backgroundActivityLogger: The logger to use for misconfiguration and background activity. By default, a print logger will be used, and if set to `nil`, a no-op logger will be used in release builds. When running in a server environment, your shared logger should be used instead giving you full control of logging and metadata.
    ///   - eventLoopGroupProvider: The event loop to use for the internal HTTP client.
    public init(
        vapidConfiguration: VAPID.Configuration,
        networkConfiguration: NetworkConfiguration = .default,
        backgroundActivityLogger: Logger? = .defaultWebPushPrintLogger,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .shared(.singletonMultiThreadedEventLoopGroup)
    ) {
        let backgroundActivityLogger = backgroundActivityLogger ?? .defaultWebPushNoOpLogger
        
        var httpClientConfiguration = HTTPClient.Configuration()
        httpClientConfiguration.httpVersion = .automatic
        httpClientConfiguration.timeout.connect = TimeAmount(networkConfiguration.connectionTimeout)
        httpClientConfiguration.timeout.read = networkConfiguration.confirmationTimeout.map { TimeAmount($0) }
        httpClientConfiguration.timeout.write = networkConfiguration.sendTimeout.map { TimeAmount($0) }
        httpClientConfiguration.proxy = networkConfiguration.httpProxy
        /// Apple's push service recomments leaving the connection open as long as possible. We are picking 12 hours here.
        /// - SeeAlso: [Sending notification requests to APNs: Follow best practices while sending push notifications with APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns#Follow-best-practices-while-sending-push-notifications-with-APNs)
        httpClientConfiguration.connectionPool.idleTimeout = .hours(12)
        
        let executor: Executor = switch eventLoopGroupProvider {
        case .shared(let eventLoopGroup):
            .httpClient(HTTPClient(
                eventLoopGroupProvider: .shared(eventLoopGroup),
                configuration: httpClientConfiguration,
                backgroundActivityLogger: backgroundActivityLogger
            ))
        case .createNew:
            .httpClient(HTTPClient(
                configuration: httpClientConfiguration,
                backgroundActivityLogger: backgroundActivityLogger
            ))
        }
        
        self.init(
            vapidConfiguration: vapidConfiguration,
            networkConfiguration: networkConfiguration,
            backgroundActivityLogger: backgroundActivityLogger,
            executor: executor
        )
    }
    
    /// Initialize a manager with an unsafe HTTP Client.
    ///
    /// - Note: You should generally not need to share an HTTP client — in fact, it is heavily discouraged, but provided as an override point should it be necessary. Instead, opt to customize a ``NetworkConfiguration-swift.struct`` and pass it to ``init(vapidConfiguration:networkConfiguration:backgroundActivityLogger:eventLoopGroupProvider:)``, or use `WebPushTesting`'s ``WebPushManager/makeMockedManager(vapidConfiguration:backgroundActivityLogger:messageHandlers:)`` if you intended to mock a ``WebPushManager`` in your tests. If these integration points are not enough, please [create an issue](https://github.com/mochidev/swift-webpush/issues) so we can support it directly.
    ///
    /// - Important: You are responsible for shutting down the client, and there is no direct benefit to using a ``WebPushManager`` as a service if you opt for this initializer.
    ///
    /// - Parameters:
    ///   - vapidConfiguration: The VAPID configuration to use when identifying the application server.
    ///   - networkConfiguration: The network configuration used when configuring the manager.
    ///   - backgroundActivityLogger: The logger to use for misconfiguration and background activity. By default, a print logger will be used, and if set to `nil`, a no-op logger will be used in release builds. When running in a server environment, your shared logger should be used instead giving you full control of logging and metadata.
    ///   - unsafeHTTPClient: A custom HTTP client to use.
    public init(
        vapidConfiguration: VAPID.Configuration,
        networkConfiguration: NetworkConfiguration = .default,
        backgroundActivityLogger: Logger? = .defaultWebPushPrintLogger,
        unsafeHTTPClient: HTTPClient
    ) {
        let backgroundActivityLogger = backgroundActivityLogger ?? .defaultWebPushNoOpLogger
        
        self.init(
            vapidConfiguration: vapidConfiguration,
            networkConfiguration: networkConfiguration,
            backgroundActivityLogger: backgroundActivityLogger,
            executor: .httpClient(unsafeHTTPClient),
            skipClientShutdown: true
        )
    }
    
    /// Internal method to install a different executor for mocking.
    /// 
    /// Note that this must be called before ``run()`` is called or the client's syncShutdown won't be called.
    /// - Parameters:
    ///   - vapidConfiguration: The VAPID configuration to use when identifying the application server.
    ///   - networkConfiguration: The network configuration used when configuring the manager.
    ///   - backgroundActivityLogger: The logger to use for misconfiguration and background activity.
    ///   - executor: The executor to use when sending push messages.
    ///   - skipClientShutdown: Whether to skip client shutdown or not.
    package init(
        vapidConfiguration: VAPID.Configuration,
        networkConfiguration: NetworkConfiguration = .default,
        backgroundActivityLogger: Logger,
        executor: Executor,
        skipClientShutdown: Bool = false
    ) {
        var backgroundActivityLogger = backgroundActivityLogger
        backgroundActivityLogger[metadataKey: "vapidConfiguration"] = [
            "contactInformation" : "\(vapidConfiguration.contactInformation)",
            "primaryKey" : "\(vapidConfiguration.primaryKey?.id.description ?? "nil")",
            "keys" : .array(vapidConfiguration.keys.map { .string($0.id.description) }),
            "deprecatedKeys" : .array((vapidConfiguration.deprecatedKeys ?? []).map { .string($0.id.description) }),
            "validityDuration" : "\(vapidConfiguration.validityDuration)",
            "expirationDuration" : "\(vapidConfiguration.expirationDuration)",
        ]
        
        if vapidConfiguration.validityDuration > vapidConfiguration.expirationDuration {
            assertionFailure("The validity duration must be earlier than the expiration duration since it represents when the VAPID Authorization token will be refreshed ahead of it expiring.")
            backgroundActivityLogger.error("The validity duration must be earlier than the expiration duration since it represents when the VAPID Authorization token will be refreshed ahead of it expiring. Run your application server with the same configuration in debug mode to catch this.")
        }
        if vapidConfiguration.expirationDuration > .hours(24) {
            assertionFailure("The expiration duration must be less than 24 hours or else push endpoints will reject messages sent to them.")
            backgroundActivityLogger.error("The expiration duration must be less than 24 hours or else push endpoints will reject messages sent to them. Run your application server with the same configuration in debug mode to catch this.")
        }
        precondition(!vapidConfiguration.keys.isEmpty, "VAPID.Configuration must have keys specified. Please report this as a bug with reproduction steps if encountered: https://github.com/mochidev/swift-webpush/issues.")
        
        self.vapidConfiguration = vapidConfiguration
        self.networkConfiguration = networkConfiguration
        let allKeys = vapidConfiguration.keys + Array(vapidConfiguration.deprecatedKeys ?? [])
        self.vapidKeyLookup = Dictionary(
            allKeys.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.backgroundActivityLogger = backgroundActivityLogger
        self.executor = executor
        self.skipClientShutdown = skipClientShutdown
    }
    
    /// Shutdown the client if it hasn't already been stopped.
    deinit {
        if !didShutdown, !skipClientShutdown, case let .httpClient(httpClient, _) = executor {
            try? httpClient.syncShutdown()
        }
    }
    
    /// Load an up-to-date Authorization header for the specified endpoint and signing key combo.
    /// - Parameters:
    ///   - endpoint: The endpoint we'll be contacting to send push messages for a given subscriber.
    ///   - signingKey: The signing key to sign the authorization token with.
    /// - Returns: An `Authorization` header string.
    func loadCurrentVAPIDAuthorizationHeader(
        endpoint: URL,
        signingKey: VAPID.Key
    ) throws -> String {
        let origin = endpoint.origin
        let cacheKey = "\(signingKey.id)|\(origin)"
        
        let now = Date()
        let expirationDate = min(now.adding(vapidConfiguration.expirationDuration), now.adding(.hours(24)))
        let renewalDate = min(now.adding(vapidConfiguration.validityDuration), expirationDate)
        
        if let cachedHeader = vapidAuthorizationCache[cacheKey],
           now < cachedHeader.validUntil
        { return cachedHeader.authorization }
        
        let token = VAPID.Token(
            origin: origin,
            contactInformation: vapidConfiguration.contactInformation,
            expiration: expirationDate
        )
        
        let authorization = try token.generateAuthorization(signedBy: signingKey)
        vapidAuthorizationCache[cacheKey] = (authorization, validUntil: renewalDate)
        
        return authorization
    }
    
    /// Request a VAPID key to supply to the client when requesting a new subscription.
    ///
    /// The ID returned is already in a format that browsers expect `applicationServerKey` to be:
    /// ```js
    /// const serviceRegistration = await navigator.serviceWorker?.register("/serviceWorker.mjs", { type: "module" });
    /// const applicationServerKey = await loadVAPIDKey();
    /// const subscription = await serviceRegistration.pushManager.subscribe({
    ///     userVisibleOnly: true,
    ///     applicationServerKey,
    /// });
    ///
    /// ...
    ///
    /// async function loadVAPIDKey() {
    ///     const httpResponse = await fetch(`/vapidKey`);
    ///
    ///     const webPushOptions = await httpResponse.json();
    ///     if (httpResponse.status != 200) throw new Error(webPushOptions.reason);
    ///
    ///     return webPushOptions.vapid;
    /// }
    /// ```
    ///
    /// Simply provide a route to supply the key, as shown for Vapor below:
    /// ```swift
    /// app.get("vapidKey", use: loadVapidKey)
    ///
    /// ...
    ///
    /// struct WebPushOptions: Codable, Content, Hashable, Sendable {
    ///     static let defaultContentType = HTTPMediaType(type: "application", subType: "webpush-options+json")
    ///
    ///     var vapid: VAPID.Key.ID
    /// }
    ///
    /// @Sendable func loadVapidKey(request: Request) async throws -> WebPushOptions {
    ///     WebPushOptions(vapid: manager.nextVAPIDKeyID)
    /// }
    /// ```
    ///
    /// - Note: If you supplied multiple keys in your VAPID configuration, you must specify the key ID along with the subscription you received from the browser. This can be easily done client side:
    /// ```js
    /// export async function registerSubscription(subscription, applicationServerKey) {
    ///     const subscriptionStatusResponse = await fetch(`/registerSubscription`, {
    ///         method: "POST",
    ///         body: {
    ///             ...subscription.toJSON(),
    ///             applicationServerKey
    ///         }
    ///     });
    ///
    ///     ...
    /// }
    /// ```
    public nonisolated var nextVAPIDKeyID: VAPID.Key.ID {
        vapidConfiguration.primaryKey?.id ?? vapidConfiguration.keys.randomElement()!.id
    }
    
    /// Check the status of a key against the current configuration.
    public nonisolated func keyStatus(for keyID: VAPID.Key.ID) -> VAPID.Configuration.KeyStatus {
        guard let key = vapidKeyLookup[keyID]
        else { return .unknown }
        
        if vapidConfiguration.deprecatedKeys?.contains(key) == true {
            return .deprecated
        }
        
        return .valid
    }
    
    /// Send a push message as raw data.
    ///
    /// The service worker you registered is expected to know how to decode the data you send.
    ///
    /// - Parameters:
    ///   - message: The message to send as raw data.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - deduplicationTopic: The topic to use when deduplicating messages stored on a Push Service. When specifying a topic, prefer to use ``send(data:to:encodableDeduplicationTopic:expiration:urgency:logger:)`` instead.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    public func send(
        data message: some DataProtocol,
        to subscriber: some SubscriberProtocol,
        deduplicationTopic topic: Topic? = nil,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        switch executor {
        case .httpClient(let httpClient, let privateKeyProvider):
            var logger = logger ?? backgroundActivityLogger
            logger[metadataKey: "message"] = ".data(\(message.base64URLEncodedString()))"
            try await encryptPushMessage(
                httpClient: httpClient,
                privateKeyProvider: privateKeyProvider,
                data: message,
                subscriber: subscriber,
                deduplicationTopic: topic,
                expiration: expiration,
                urgency: urgency,
                logger: logger
            )
        case .handler(let handler):
            try await handler(.data(Data(message)), Subscriber(subscriber), topic, expiration, urgency)
        }
    }
    
    /// Send a push message as raw data.
    ///
    /// The service worker you registered is expected to know how to decode the data you send.
    ///
    /// - Parameters:
    ///   - message: The message to send as raw data.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - encodableDeduplicationTopic: The topic to use when deduplicating messages stored on a Push Service.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    @inlinable
    public func send(
        data message: some DataProtocol,
        to subscriber: some SubscriberProtocol,
        encodableDeduplicationTopic: some Encodable,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await send(
            data: message,
            to: subscriber,
            deduplicationTopic: Topic(
                encodableTopic: encodableDeduplicationTopic,
                salt: subscriber.userAgentKeyMaterial.authenticationSecret
            ),
            expiration: expiration,
            urgency: urgency,
            logger: logger
        )
    }
    
    /// Check to see if a message is potentially too large to be sent to a push service.
    ///
    /// - Note: _Some_ push services may still accept larger messages, so you can only truly know if a message is _too_ large by attempting to send it and checking for a ``MessageTooLargeError`` error. However, if a message passes this check, it is guaranteed to not fail for this reason, assuming the push service implements the minimum requirements of the spec, which you can assume for all major browsers.
    ///
    /// - Parameters:
    ///   - message: The message to send as raw data.
    /// - Throws: ``MessageTooLargeError`` if the message is too large.
    @inlinable
    public nonisolated func checkMessageSize(data message: some DataProtocol) throws(MessageTooLargeError) {
        guard message.count <= Self.maximumMessageSize
        else { throw MessageTooLargeError() }
    }
    
    /// Send a push message as a string.
    ///
    /// The service worker you registered is expected to know how to decode the string you send.
    ///
    /// - Parameters:
    ///   - message: The message to send as a string.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - deduplicationTopic: The topic to use when deduplicating messages stored on a Push Service. When specifying a topic, prefer to use ``send(string:to:encodableDeduplicationTopic:expiration:urgency:logger:)`` instead.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    public func send(
        string message: some StringProtocol,
        to subscriber: some SubscriberProtocol,
        deduplicationTopic topic: Topic? = nil,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await routeMessage(
            message: .string(String(message)),
            to: subscriber,
            deduplicationTopic: topic,
            expiration: expiration,
            urgency: urgency,
            logger: logger ?? backgroundActivityLogger
        )
    }
    
    /// Send a push message as a string.
    ///
    /// The service worker you registered is expected to know how to decode the string you send.
    ///
    /// - Parameters:
    ///   - message: The message to send as a string.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - encodableDeduplicationTopic: The topic to use when deduplicating messages stored on a Push Service.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    @inlinable
    public func send(
        string message: some StringProtocol,
        to subscriber: some SubscriberProtocol,
        encodableDeduplicationTopic: some Encodable,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await send(
            string: message,
            to: subscriber,
            deduplicationTopic: Topic(
                encodableTopic: encodableDeduplicationTopic,
                salt: subscriber.userAgentKeyMaterial.authenticationSecret
            ),
            expiration: expiration,
            urgency: urgency,
            logger: logger
        )
    }
    
    /// Check to see if a message is potentially too large to be sent to a push service.
    ///
    /// - Note: _Some_ push services may still accept larger messages, so you can only truly know if a message is _too_ large by attempting to send it and checking for a ``MessageTooLargeError`` error. However, if a message passes this check, it is guaranteed to not fail for this reason, assuming the push service implements the minimum requirements of the spec, which you can assume for all major browsers. For these reasons, unless you are sending the same message to multiple subscribers, it's often faster to just try sending the message rather than checking before sending.
    ///
    /// - Parameters:
    ///   - message: The message to send as a string.
    /// - Throws: ``MessageTooLargeError`` if the message is too large.
    @inlinable
    public nonisolated func checkMessageSize(string message: some StringProtocol) throws(MessageTooLargeError) {
        guard message.utf8.count <= Self.maximumMessageSize
        else { throw MessageTooLargeError() }
    }
    
    /// Send a push message as encoded JSON.
    ///
    /// The service worker you registered is expected to know how to decode the JSON you send. Note that dates are encoded using ``/Foundation/JSONEncoder/DateEncodingStrategy/millisecondsSince1970``, and data is encoded using ``/Foundation/JSONEncoder/DataEncodingStrategy/base64``.
    ///
    /// - Parameters:
    ///   - message: The message to send as JSON.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - deduplicationTopic: The topic to use when deduplicating messages stored on a Push Service. When specifying a topic, prefer to use ``send(json:to:encodableDeduplicationTopic:expiration:urgency:logger:)`` instead.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    public func send(
        json message: some Encodable&Sendable,
        to subscriber: some SubscriberProtocol,
        deduplicationTopic topic: Topic? = nil,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await routeMessage(
            message: .json(message),
            to: subscriber,
            deduplicationTopic: topic,
            expiration: expiration,
            urgency: urgency,
            logger: logger ?? backgroundActivityLogger
        )
    }
    
    /// Send a push message as encoded JSON.
    ///
    /// The service worker you registered is expected to know how to decode the JSON you send. Note that dates are encoded using ``/Foundation/JSONEncoder/DateEncodingStrategy/millisecondsSince1970``, and data is encoded using ``/Foundation/JSONEncoder/DataEncodingStrategy/base64``.
    ///
    /// - Parameters:
    ///   - message: The message to send as JSON.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - encodableDeduplicationTopic: The topic to use when deduplicating messages stored on a Push Service.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    @inlinable
    public func send(
        json message: some Encodable&Sendable,
        to subscriber: some SubscriberProtocol,
        encodableDeduplicationTopic: some Encodable,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await send(
            json: message,
            to: subscriber,
            deduplicationTopic: Topic(
                encodableTopic: encodableDeduplicationTopic,
                salt: subscriber.userAgentKeyMaterial.authenticationSecret
            ),
            expiration: expiration,
            urgency: urgency,
            logger: logger
        )
    }
    
    /// Check to see if a message is potentially too large to be sent to a push service.
    ///
    /// - Note: _Some_ push services may still accept larger messages, so you can only truly know if a message is _too_ large by attempting to send it and checking for a ``MessageTooLargeError`` error. However, if a message passes this check, it is guaranteed to not fail for this reason, assuming the push service implements the minimum requirements of the spec, which you can assume for all major browsers. For these reasons, unless you are sending the same message to multiple subscribers, it's often faster to just try sending the message rather than checking before sending.
    ///
    /// - Parameters:
    ///   - message: The message to send as JSON.
    /// - Throws: ``MessageTooLargeError`` if the message is too large. Throws another error if encoding fails.
    @inlinable
    public nonisolated func checkMessageSize(json message: some Encodable&Sendable) throws {
        try _Message.json(message).checkMessageSize()
    }
    
    /// Send a push notification.
    ///
    /// If you provide ``PushMessage/Notification/data``, the service worker you registered is expected to know how to decode it. Note that dates are encoded using ``/Foundation/JSONEncoder/DateEncodingStrategy/millisecondsSince1970``, and data is encoded using ``/Foundation/JSONEncoder/DataEncodingStrategy/base64``.
    ///
    /// - Parameters:
    ///   - notification: The ``PushMessage/Notification`` push notification.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - deduplicationTopic: The topic to use when deduplicating messages stored on a Push Service. When specifying a topic, prefer to use ``send(json:to:encodableDeduplicationTopic:expiration:urgency:logger:)`` instead.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    public func send<Contents>(
        notification: PushMessage.Notification<Contents>,
        to subscriber: some SubscriberProtocol,
        deduplicationTopic topic: Topic? = nil,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await send(
            json: notification,
            to: subscriber,
            deduplicationTopic: topic,
            expiration: expiration,
            urgency: urgency,
            logger: logger
        )
    }
    
    /// Send a push notification.
    ///
    /// If you provide ``PushMessage/Notification/data``, the service worker you registered is expected to know how to decode it. Note that dates are encoded using ``/Foundation/JSONEncoder/DateEncodingStrategy/millisecondsSince1970``, and data is encoded using ``/Foundation/JSONEncoder/DataEncodingStrategy/base64``.
    ///
    /// - Parameters:
    ///   - notification: The ``PushMessage/Notification`` push notification.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - encodableDeduplicationTopic: The topic to use when deduplicating messages stored on a Push Service.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    ///   - logger: The logger to use for status updates. If not provided, the background activity logger will be used instead. When running in a server environment, your contextual logger should be used instead giving you full control of logging and metadata.
    @inlinable
    public func send<Contents>(
        notification: PushMessage.Notification<Contents>,
        to subscriber: some SubscriberProtocol,
        encodableDeduplicationTopic: some Encodable,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high,
        logger: Logger? = nil
    ) async throws {
        try await send(
            json: notification,
            to: subscriber,
            encodableDeduplicationTopic: encodableDeduplicationTopic,
            expiration: expiration,
            urgency: urgency,
            logger: logger
        )
    }
    
    /// Check to see if a message is potentially too large to be sent to a push service.
    ///
    /// - Note: _Some_ push services may still accept larger messages, so you can only truly know if a message is _too_ large by attempting to send it and checking for a ``MessageTooLargeError`` error. However, if a message passes this check, it is guaranteed to not fail for this reason, assuming the push service implements the minimum requirements of the spec, which you can assume for all major browsers. For these reasons, unless you are sending the same message to multiple subscribers, it's often faster to just try sending the message rather than checking before sending.
    ///
    /// - Parameters:
    ///   - notification: The ``PushMessage/Notification`` push notification.
    /// - Throws: ``MessageTooLargeError`` if the message is too large. Throws another error if encoding fails.
    @inlinable
    public nonisolated func checkMessageSize<Contents>(notification: PushMessage.Notification<Contents>) throws {
        try notification.checkMessageSize()
    }
    
    /// Route a message to the current executor.
    /// - Parameters:
    ///   - message: The message to send.
    ///   - subscriber: The subscriber to sign the message against.
    ///   - deduplicationTopic: The topic to use when deduplicating messages stored on a Push Service.
    ///   - expiration: The expiration of the message.
    ///   - urgency: The urgency of the message.
    ///   - logger: The logger to use for status updates.
    func routeMessage(
        message: _Message,
        to subscriber: some SubscriberProtocol,
        deduplicationTopic topic: Topic?,
        expiration: Expiration,
        urgency: Urgency,
        logger: Logger
    ) async throws {
        var logger = logger
        logger[metadataKey: "message"] = "\(message)"
        switch executor {
        case .httpClient(let httpClient, let privateKeyProvider):
            try await encryptPushMessage(
                httpClient: httpClient,
                privateKeyProvider: privateKeyProvider,
                data: message.data,
                subscriber: subscriber,
                deduplicationTopic: topic,
                expiration: expiration,
                urgency: urgency,
                logger: logger
            )
        case .handler(let handler):
            try await handler(
                message,
                Subscriber(subscriber),
                topic,
                expiration,
                urgency
            )
        }
    }
    
    /// Send a message via HTTP Client, mocked or otherwise, encrypting it on the way.
    /// - Parameters:
    ///   - httpClient: The protocol implementing HTTP-like functionality.
    ///   - privateKeyProvider: The private key to use for the key exchange. If nil, one will be generated.
    ///   - message: The message to send as raw data.
    ///   - subscriber: The subscriber to sign the message against.
    ///   - deduplicationTopic: The topic to use when deduplicating messages stored on a Push Service.
    ///   - expiration: The expiration of the message.
    ///   - urgency: The urgency of the message.
    ///   - logger: The logger to use for status updates.
    func encryptPushMessage(
        httpClient: some HTTPClientProtocol,
        privateKeyProvider: Executor.KeyProvider,
        data message: some DataProtocol,
        subscriber: some SubscriberProtocol,
        deduplicationTopic topic: Topic?,
        expiration: Expiration,
        urgency: Urgency,
        logger: Logger
    ) async throws {
        let clock = ContinuousClock()
        let startTime = clock.now
        
        var logger = logger
        logger[metadataKey: "subscriber"] = [
            "vapidKeyID" : "\(subscriber.vapidKeyID)",
            "endpoint" : "\(subscriber.endpoint)",
        ]
        logger[metadataKey: "expiration"] = "\(expiration)"
        logger[metadataKey: "urgency"] = "\(urgency)"
        logger[metadataKey: "origin"] = "\(subscriber.endpoint.origin)"
        logger[metadataKey: "messageSize"] = "\(message.count)"
        logger[metadataKey: "topic"] = "\(topic?.description ?? "nil")"
        
        /// Force a random topic so any retries don't get duplicated when the option is set.
        var topic = topic
        if networkConfiguration.alwaysResolveTopics {
            let resolvedTopic = topic ?? Topic()
            logger[metadataKey: "resolvedTopic"] = "\(resolvedTopic)"
            topic = resolvedTopic
        }
        logger.trace("Sending notification")
        
        guard let signingKey = vapidKeyLookup[subscriber.vapidKeyID] else {
            logger.warning("A key was not found for this subscriber.")
            throw VAPID.ConfigurationError.matchingKeyNotFound
        }
        
        /// Prepare authorization, private keys, and payload ahead of time to bail early if they can't be created.
        let authorization = try loadCurrentVAPIDAuthorizationHeader(endpoint: subscriber.endpoint, signingKey: signingKey)
        let applicationServerECDHPrivateKey: P256.KeyAgreement.PrivateKey
        
        /// Perform key exchange between the user agent's public key and our private key, deriving a shared secret.
        let userAgent = subscriber.userAgentKeyMaterial
        let sharedSecret: SharedSecret
        do {
            (applicationServerECDHPrivateKey, sharedSecret) = try privateKeyProvider.sharedSecretFromKeyAgreement(with: userAgent.publicKey)
        } catch {
            logger.debug("A shared secret could not be derived from the subscriber's public key and the newly-generated private key.", metadata: ["error" : "\(error)"])
            throw BadSubscriberError()
        }
        
        /// Generate a 16-byte salt.
        var salt: [UInt8] = Array(repeating: 0, count: 16)
        for index in salt.indices { salt[index] = .random(in: .min ... .max) }
        
        if message.count > Self.maximumMessageSize {
            logger.warning("Push message is longer than the maximum guarantee made by the spec: \(Self.maximumMessageSize) bytes. Sending this message may fail, and its size will be leaked despite being encrypted. Please consider sending less data to keep your communications secure.")
        }
        
        /// Prepare the payload by padding it so the final message is 4KB.
        /// Remove 103 bytes for the theoretical plaintext maximum to achieve this:
        /// - 16 bytes for the auth tag,
        /// - 1 for the minimum padding byte (0x02)
        /// - 86 bytes for the contentCodingHeader:
        ///     - 16 bytes for the salt
        ///     - 4 bytes for the record size
        ///     - 1 byte for the key ID size
        ///     - 65 bytes for the X9.62/3 representation of the public key
        ///         - 1 bye for 0x04
        ///         - 32 bytes for x coordinate
        ///         - 32 bytes for y coordinate
        let paddedPayloadSize = max(message.count, Self.maximumMessageSize) // 3993
        let paddedPayload = message + [0x02] + Array(repeating: 0, count: paddedPayloadSize - message.count)
        
        /// Prepare the remaining coding header values:
        let recordSize = UInt32(paddedPayload.count + 16)
        let keyID = applicationServerECDHPrivateKey.publicKey.x963Representation
        let keyIDSize = UInt8(keyID.count)
        let contentCodingHeader = salt + recordSize.bigEndianBytes + keyIDSize.bigEndianBytes + keyID
        
        /// Derive key material (IKM) from the shared secret, salted with the public key pairs and the user agent's authentication salt.
        let keyInfo = "WebPush: info".utf8Bytes + [0x00] + userAgent.publicKey.x963Representation + applicationServerECDHPrivateKey.publicKey.x963Representation
        let inputKeyMaterial = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: userAgent.authenticationSecret,
            sharedInfo: keyInfo,
            outputByteCount: 32
        )
        
        /// Derive the content encryption key (CEK) for the AES transformation from the above input key material and the local salt.
        let contentEncryptionKeyInfo = "Content-Encoding: aes128gcm".utf8Bytes + [0x00]
        let contentEncryptionKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: salt, info: contentEncryptionKeyInfo, outputByteCount: 16)
        
        /// Similarly, derive a nonce using a different rotation of the same key material and salt. Note that we need to transform from a Symmetric key to a nonce
        let nonceInfo = "Content-Encoding: nonce".utf8Bytes + [0x00]
        let nonce = try HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: salt, info: nonceInfo, outputByteCount: 12)
            .withUnsafeBytes(AES.GCM.Nonce.init(data:))
        
        /// Encrypt the padded payload into a single record.
        /// - SeeAlso: [RFC 8188 — Encrypted Content-Encoding for HTTP](https://datatracker.ietf.org/doc/html/rfc8188)
        let encryptedRecord = try AES.GCM.seal(paddedPayload, using: contentEncryptionKey, nonce: nonce)
        
        /// Attach the header with our public key and salt, along with the authentication tag.
        let requestContent = contentCodingHeader + encryptedRecord.ciphertext + encryptedRecord.tag
        
        if expiration < Expiration.dropIfUndeliverable {
            logger.error("The message expiration must be greater than or equal to \(Expiration.dropIfUndeliverable) seconds.")
        } else if expiration > Expiration.recommendedMaximum {
            logger.warning("The message expiration should be less than \(Expiration.recommendedMaximum) seconds.")
        }
        
        let expirationDeadline: ContinuousClock.Instant? = if expiration == .dropIfUndeliverable || expiration == .recommendedMaximum {
            nil
        } else {
            startTime.advanced(by: .seconds(max(expiration, .dropIfUndeliverable).seconds))
        }
        
        /// Build and send the request.
        try await executeRequest(
            httpClient: httpClient,
            endpointURLString: subscriber.endpoint.absoluteURL.absoluteString,
            authorization: authorization,
            expiration: expiration,
            urgency: urgency,
            topic: topic,
            requestContent: requestContent,
            clock: clock,
            expirationDeadline: expirationDeadline,
            retryIntervals: networkConfiguration.retryIntervals[...],
            logger: logger
        )
    }
    
    func executeRequest(
        httpClient: some HTTPClientProtocol,
        endpointURLString: String,
        authorization: String,
        expiration: Expiration,
        urgency: Urgency,
        topic: Topic?,
        requestContent: [UInt8],
        clock: ContinuousClock,
        expirationDeadline: ContinuousClock.Instant?,
        retryIntervals: ArraySlice<Duration>,
        logger: Logger
    ) async throws {
        var logger = logger
        logger[metadataKey: "retryDurationsRemaining"] = .array(retryIntervals.map { "\($0.components.seconds)seconds" })
        
        var expiration = expiration
        var requestDeadline = NIODeadline.distantFuture
        if let expirationDeadline {
            let remainingDuration = clock.now.duration(to: expirationDeadline)
            expiration = Expiration(seconds: Int(remainingDuration.components.seconds))
            requestDeadline = .now() + TimeAmount(remainingDuration)
            logger[metadataKey: "resolvedExpiration"] = "\(expiration)"
            logger[metadataKey: "expirationDeadline"] = "\(expirationDeadline)"
        }
        
        logger.trace("Preparing to send push message.")
        
        /// Add the VAPID authorization and corrent content encoding and type.
        var request = HTTPClientRequest(url: endpointURLString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: authorization)
        request.headers.add(name: "Content-Encoding", value: "aes128gcm")
        request.headers.add(name: "Content-Type", value: "application/octet-stream")
        request.headers.add(name: "TTL", value: "\(max(expiration, .dropIfUndeliverable).seconds)")
        request.headers.add(name: "Urgency", value: "\(urgency)")
        if let topic {
            request.headers.add(name: "Topic", value: "\(topic)")
        }
        request.body = .bytes(ByteBuffer(bytes: requestContent))
        
        /// Send the request to the push endpoint.
        let response = try await httpClient.execute(request, deadline: requestDeadline, logger: logger)
        logger[metadataKey: "response"] = "\(response)"
        logger[metadataKey: "statusCode"] = "\(response.status)"
        logger.trace("Sent push message.")
        
        /// Check the response and determine if the subscription should be removed from our records, or if the notification should just be skipped.
        switch response.status {
        case .created: break
        case .notFound, .gone: throw BadSubscriberError()
        case .payloadTooLarge:
            logger.error("The encrypted payload was too large and was rejected by the push service.")
            throw MessageTooLargeError()
        case .tooManyRequests, .internalServerError, .serviceUnavailable:
            /// 429 too many requests, 500 internal server error, 503 server shutting down are all opportunities to just retry if we can, otherwise throw the error
            guard let retryInterval = retryIntervals.first else {
                logger.trace("Message was rejected, no retries remaining.")
                throw PushServiceError(response: response)
            }
            logger.trace("Message was rejected, but can be retried.")
            
            try await Task.sleep(for: retryInterval)
            try await executeRequest(
                httpClient: httpClient,
                endpointURLString: endpointURLString,
                authorization: authorization,
                expiration: expiration,
                urgency: urgency,
                topic: topic,
                requestContent: requestContent,
                clock: clock,
                expirationDeadline: expirationDeadline,
                retryIntervals: retryIntervals.dropFirst(),
                logger: logger
            )
        default: throw PushServiceError(response: response)
        }
        logger.trace("Successfully sent push message.")
    }
}

extension WebPushManager: Service {
    public func run() async throws {
        backgroundActivityLogger.debug("Starting up WebPushManager")
        guard !didShutdown else {
            assertionFailure("The manager was already shutdown and cannot be started.")
            backgroundActivityLogger.error("The manager was already shutdown and cannot be started. Run your application server in debug mode to catch this.")
            return
        }
        try await withTaskCancellationOrGracefulShutdownHandler {
            try await gracefulShutdown()
        } onCancelOrGracefulShutdown: { [skipClientShutdown, backgroundActivityLogger, executor] in
            backgroundActivityLogger.debug("Shutting down WebPushManager")
            do {
                if !skipClientShutdown, case let .httpClient(httpClient, _) = executor {
                    try httpClient.syncShutdown()
                }
            } catch {
                backgroundActivityLogger.error("Graceful Shutdown Failed", metadata: [
                    "error": "\(error)"
                ])
            }
        }
        didShutdown = true
    }
}

// MARK: - Public Types

extension WebPushManager {
    /// A duration in seconds used to express when push messages will expire.
    ///
    /// - SeeAlso: [RFC 8030 — Generic Event Delivery Using HTTP §5.2. Push Message Time-To-Live](https://datatracker.ietf.org/doc/html/rfc8030#section-5.2)
    public struct Expiration: Hashable, Comparable, Codable, ExpressibleByIntegerLiteral, AdditiveArithmetic, Sendable {
        /// The number of seconds represented by this expiration.
        public let seconds: Int
        
        /// The recommended maximum expiration duration push services are expected to support.
        ///
        /// - Note: A time of 30 days was chosen to match the maximum Apple Push Notification Services (APNS) accepts, but there is otherwise no recommended value here. Note that other services are instead limited to 4 weeks, or 28 days.
        public static let recommendedMaximum: Self = .days(30)
        
        /// The message will be delivered immediately, otherwise it'll be dropped.
        ///
        /// A Push message with a zero TTL is immediately delivered if the user agent is available to receive the message. After delivery, the push service is permitted to immediately remove a push message with a zero TTL. This might occur before the user agent acknowledges receipt of the message by performing an HTTP DELETE on the push message resource. Consequently, an application server cannot rely on receiving acknowledgement receipts for zero TTL push messages.
        ///
        /// If the user agent is unavailable, a push message with a zero TTL expires and is never delivered.
        ///
        /// - SeeAlso: [RFC 8030 — Generic Event Delivery Using HTTP §5.2. Push Message Time-To-Live](https://datatracker.ietf.org/doc/html/rfc8030#section-5.2)
        public static let dropIfUndeliverable: Self = .zero
        
        /// Initialize an expiration with a number of seconds.
        @inlinable
        public init(seconds: Int) {
            self.seconds = seconds
        }
        
        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.seconds < rhs.seconds
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.seconds = try container.decode(Int.self)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.seconds)
        }
        
        @inlinable
        public init(integerLiteral value: Int) {
            self.seconds = value
        }
        
        @inlinable
        public static func - (lhs: Self, rhs: Self) -> Self {
            Self(seconds: lhs.seconds - rhs.seconds)
        }
        
        @inlinable
        public static func + (lhs: Self, rhs: Self) -> Self {
            Self(seconds: lhs.seconds + rhs.seconds)
        }
        
        /// Make an expiration with a number of seconds.
        @inlinable
        public static func seconds(_ seconds: Int) -> Self {
            Self(seconds: seconds)
        }
        
        /// Make an expiration with a number of minutes.
        @inlinable
        public static func minutes(_ minutes: Int) -> Self {
            .seconds(minutes*60)
        }
        
        /// Make an expiration with a number of hours.
        @inlinable
        public static func hours(_ hours: Int) -> Self {
            .minutes(hours*60)
        }
        
        /// Make an expiration with a number of days.
        @inlinable
        public static func days(_ days: Int) -> Self {
            .hours(days*24)
        }
    }
}

extension WebPushManager {
    /// The urgency with which to deliver a push message.
    ///
    /// - SeeAlso: [RFC 8030 — Generic Event Delivery Using HTTP §5.3. Push Message Urgency](https://datatracker.ietf.org/doc/html/rfc8030#section-5.3)
    public struct Urgency: Hashable, Comparable, Sendable, CustomStringConvertible {
        /// The internal raw value that is encoded in this type's place when calling ``description``.
        let rawValue: String
        
        /// An urgency intended only for devices on power and Wi-Fi.
        ///
        /// For instance, very low ugency messages are ideal for advertisements.
        public static let veryLow = Self(rawValue: "very-low")
        
        /// An urgency intended for devices on either power or Wi-Fi.
        ///
        /// For instance, low ugency messages are ideal for topic updates.
        public static let low = Self(rawValue: "low")
        
        /// An urgency intended for devices on neither power nor Wi-Fi.
        ///
        /// For instance, normal ugency messages are ideal for chat or calendar messages.
        public static let normal = Self(rawValue: "normal")
        
        /// An urgency intended for devices even with low battery.
        ///
        /// For instance, high ugency messages are ideal for incoming phone calls or time-sensitive alerts.
        public static let high = Self(rawValue: "high")
        
        /// An internal sort order for urgencies.
        @usableFromInline
        var comparableValue: Int {
            switch self {
            case .high:     4
            case .normal:   3
            case .low:      2
            case .veryLow:  1
            default:        0
            }
        }
        
        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.comparableValue < rhs.comparableValue
        }
        
        public var description: String { rawValue }
    }
}

extension WebPushManager.Urgency: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension WebPushManager {
    /// The network configuration for a web push manager.
    public struct NetworkConfiguration: Hashable, Sendable {
        /// A list of intervals to wait between automatic retries.
        ///
        /// Only some push service errors can safely be automatically retried. When one such error is encountered, this list is used to wait a set amount of time after a compatible failure, then perform a retry, adjusting expiration values as needed.
        ///
        /// Specify `[]` to disable retries.
        public var retryIntervals: [Duration]
        
        /// A flag to automatically generate a random `Topic` to prevent messages that are automatically retried from being delivered twice.
        ///
        /// This is usually not necessary for a compliant push service, but can be turned on if you are experiencing the same message being delivered twice when a retry occurs.
        public var alwaysResolveTopics: Bool
        
        /// A timeout before a connection is dropped.
        public var connectionTimeout: Duration
        
        /// A timeout before we abandon the connection due to messages not being sent.
        ///
        /// If `nil`, no timeout will be used.
        public var sendTimeout: Duration?
        
        /// A timeout before we abondon the connection due to the push service not sending back acknowledgement a message was received.
        ///
        /// If `nil`, no timeout will be used.
        public var confirmationTimeout: Duration?
        
        /// An HTTP proxy to use when communicating to a push service.
        ///
        /// If `nil`, no proxy will be used.
        public var httpProxy: HTTPClient.Configuration.Proxy?
        
        /// Initialize a new network configuration.
        /// - Parameters:
        ///   - retryIntervals: A list of intervals to wait between automatic retries before giving up. Defaults to a maximum of three retries.
        ///   - alwaysResolveTopics: A flag to automatically generate a random `Topic` to prevent messages that are automatically retried from being delivered twice. Defaults to `false`.
        ///   - connectionTimeout: A timeout before a connection is dropped. Defaults to 10 seconds
        ///   - sendTimeout: A timeout before we abandon the connection due to messages not being sent. Defaults to no timeout.
        ///   - confirmationTimeout: A timeout before we abondon the connection due to the push service not sending back acknowledgement a message was received. Defaults to no timeout.
        ///   - httpProxy: An HTTP proxy to use when communicating to a push service. Defaults to no proxy.
        public init(
            retryIntervals: [Duration] = [.milliseconds(500), .seconds(2), .seconds(10)],
            alwaysResolveTopics: Bool = false,
            connectionTimeout: Duration? = nil,
            sendTimeout: Duration? = nil,
            confirmationTimeout: Duration? = nil,
            httpProxy: HTTPClient.Configuration.Proxy? = nil
        ) {
            self.retryIntervals = retryIntervals
            self.alwaysResolveTopics = alwaysResolveTopics
            self.connectionTimeout = connectionTimeout ?? .seconds(10)
            self.sendTimeout = sendTimeout
            self.confirmationTimeout = confirmationTimeout
            self.httpProxy = httpProxy
        }
        
        public static let `default` = NetworkConfiguration()
    }
}

// MARK: - Package Types

extension WebPushManager {
    /// An internal type representing a push message, accessible when using ``/WebPushTesting``.
    ///
    /// - Warning: Never switch on the message type, as values may be added to it over time.
    public enum _Message: Sendable, CustomStringConvertible {
        /// A message originally sent via ``WebPushManager/send(data:to:expiration:urgency:)``
        case data(Data)
        
        /// A message originally sent via ``WebPushManager/send(string:to:expiration:urgency:)``
        case string(String)
        
        /// A message originally sent via ``WebPushManager/send(json:to:expiration:urgency:)``
        case json(any Encodable&Sendable)
        
        /// The message, encoded as data.
        @usableFromInline
        var data: Data {
            get throws {
                switch self {
                case .data(let data):
                    return data
                case .string(let string):
                    var string = string
                    return string.withUTF8 { Data($0) }
                case .json(let json):
                    return try WebPushManager.messageEncoder.encode(json)
                }
            }
        }
        
        /// The string value from a ``string(_:)`` message.
        @inlinable
        public var string: String? {
            guard case let .string(string) = self
            else { return nil }
            return string
        }
        
        /// The json value from a ``json(_:)`` message.
        @inlinable
        public func json<JSON: Encodable&Sendable>(as: JSON.Type = JSON.self) -> JSON? {
            guard case let .json(json) = self
            else { return nil }
            return json as? JSON
        }
        
        @inlinable
        public var description: String {
            switch self {
            case .data(let data):
                return ".data(\(data.base64URLEncodedString()))"
            case .string(let string):
                return ".string(\(string))"
            case .json(let json):
                return ".json(\(json))"
            }
        }
        
        /// Check to see if a message is potentially too large to be sent to a push service.
        ///
        /// - Note: _Some_ push services may still accept larger messages, so you can only truly know if a message is _too_ large by attempting to send it and checking for a ``MessageTooLargeError`` error. However, if a message passes this check, it is guaranteed to not fail for this reason, assuming the push service implements the minimum requirements of the spec, which you can assume for all major browsers. For these reasons, unless you are sending the same message to multiple subscribers, it's often faster to just try sending the message rather than checking before sending.
        ///
        /// - Throws: ``MessageTooLargeError`` if the message is too large. Throws another error if encoding fails.
        @inlinable
        public func checkMessageSize() throws {
            switch self {
            case .data(let data):
                guard data.count <= WebPushManager.maximumMessageSize
                else { throw MessageTooLargeError() }
            case .string(let string):
                guard string.utf8.count <= WebPushManager.maximumMessageSize
                else { throw MessageTooLargeError() }
            case .json(let json):
                guard try WebPushManager.messageEncoder.encode(json).count <= WebPushManager.maximumMessageSize
                else { throw MessageTooLargeError() }
            }
        }
    }
    
    /// An internal type representing the executor for a push message.
    package enum Executor: Sendable {
        /// A Private Key and Shared Secret provider.
        package enum KeyProvider: Sendable {
            /// Generate a new Private Key and Shared Secret when asked.
            case generateNew
            
            /// Used a shared generator to provide a Private Key and Shared Secret when asked.
            case shared(@Sendable (P256.KeyAgreement.PublicKey) throws -> (P256.KeyAgreement.PrivateKey, SharedSecret))
            
            /// Generate the Private Key and Shared Secret against a provided Public Key.
            func sharedSecretFromKeyAgreement(with publicKeyShare: P256.KeyAgreement.PublicKey) throws -> (P256.KeyAgreement.PrivateKey, SharedSecret) {
                switch self {
                case .generateNew:
                    let privateKey = P256.KeyAgreement.PrivateKey()
                    let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: publicKeyShare)
                    return (privateKey, sharedSecret)
                case .shared(let handler):
                    return try handler(publicKeyShare)
                }
            }
        }
        
        /// Use an HTTP client and optional private key to send an encrypted payload to a subscriber.
        ///
        /// This is used in tests to capture the encrypted request and make sure it is well-formed.
        case httpClient(any HTTPClientProtocol, KeyProvider)
        
        /// Use an HTTP client to send an encrypted payload to a subscriber.
        ///
        /// This is used in tests to capture the encrypted request and make sure it is well-formed.
        package static func httpClient(_ httpClient: any HTTPClientProtocol) -> Self {
            .httpClient(httpClient, .generateNew)
        }
        
        /// Use a handler to capture the original message.
        ///
        /// This is used by ``/WebPushTesting`` to allow mocking a ``WebPushManager``.
        case handler(@Sendable (
            _ message: _Message,
            _ subscriber: Subscriber,
            _ topic: Topic?,
            _ expiration: Expiration,
            _ urgency: Urgency
        ) async throws -> Void)
    }
}

extension Logger {
    /// A logger that will print logs by default.
    ///
    /// This is used by ``WebPushManager/init(vapidConfiguration:logger:eventLoopGroupProvider:)`` to provide a default logger when one is not provided.
    public static let defaultWebPushPrintLogger = Logger(label: "WebPushManager", factory: { PrintLogHandler(label: $0, metadataProvider: $1) })
    
    /// A logger that will not print anything by default.
    ///
    /// This is used by ``WebPushManager/init(vapidConfiguration:logger:eventLoopGroupProvider:)`` to provide a default logger when nil is specified.
    public static let defaultWebPushNoOpLogger = Logger(label: "WebPushManager", factory: { _, _ in SwiftLogNoOpLogHandler() })
}

//
//  WebPushManager.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
@preconcurrency import Crypto
import Foundation
import NIOHTTP1
import Logging
import NIOCore
import NIOPosix
import ServiceLifecycle

public actor WebPushManager: Sendable {
    public let vapidConfiguration: VAPID.Configuration
    
    /// The maximum encrypted payload size guaranteed by the spec.
    public static let maximumEncryptedPayloadSize = 4096
    
    /// The maximum message size allowed.
    public static let maximumMessageSize = maximumEncryptedPayloadSize - 103
    
    nonisolated let logger: Logger
    var executor: Executor
    
    let vapidKeyLookup: [VAPID.Key.ID : VAPID.Key]
    var vapidAuthorizationCache: [String : (authorization: String, validUntil: Date)] = [:]
    
    public init(
        vapidConfiguration: VAPID.Configuration,
        // TODO: Add networkConfiguration for proxy, number of simultaneous pushes, etc…
        logger: Logger? = nil,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .shared(.singletonMultiThreadedEventLoopGroup)
    ) {
        let logger = Logger(label: "WebPushManager", factory: { logger?.handler ?? PrintLogHandler(label: $0, metadataProvider: $1) })
        
        var httpClientConfiguration = HTTPClient.Configuration()
        httpClientConfiguration.httpVersion = .automatic
        
        let executor: Executor = switch eventLoopGroupProvider {
        case .shared(let eventLoopGroup):
            .httpClient(HTTPClient(
                eventLoopGroupProvider: .shared(eventLoopGroup),
                configuration: httpClientConfiguration,
                backgroundActivityLogger: logger
            ))
        case .createNew:
            .httpClient(HTTPClient(
                configuration: httpClientConfiguration,
                backgroundActivityLogger: logger
            ))
        }
        
        self.init(
            vapidConfiguration: vapidConfiguration,
            logger: logger,
            executor: executor
        )
    }
    
    /// Internal method to install a different executor for mocking.
    ///
    /// Note that this must be called before ``run()`` is called or the client's syncShutdown won't be called.
    package init(
        vapidConfiguration: VAPID.Configuration,
        // TODO: Add networkConfiguration for proxy, number of simultaneous pushes, etc…
        logger: Logger,
        executor: Executor
    ) {
        assert(vapidConfiguration.validityDuration <= vapidConfiguration.expirationDuration, "The validity duration must be earlier than the expiration duration since it represents when the VAPID Authorization token will be refreshed ahead of it expiring.");
        assert(vapidConfiguration.expirationDuration <= .hours(24), "The expiration duration must be less than 24 hours or else push endpoints will reject messages sent to them.");
        precondition(!vapidConfiguration.keys.isEmpty, "VAPID.Configuration must have keys specified.")
        
        self.vapidConfiguration = vapidConfiguration
        let allKeys = vapidConfiguration.keys + Array(vapidConfiguration.deprecatedKeys ?? [])
        self.vapidKeyLookup = Dictionary(
            allKeys.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.logger = logger
        self.executor = executor
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
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    public func send(
        data message: some DataProtocol,
        to subscriber: some SubscriberProtocol,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high
    ) async throws {
        switch executor {
        case .httpClient(let httpClient):
            try await execute(
                httpClient: httpClient,
                data: message,
                subscriber: subscriber,
                expiration: expiration,
                urgency: urgency
            )
        case .handler(let handler):
            try await handler(.data(Data(message)), Subscriber(subscriber), expiration, urgency)
        }
    }
    
    /// Send a push message as a string.
    ///
    /// The service worker you registered is expected to know how to decode the string you send.
    ///
    /// - Parameters:
    ///   - message: The message to send as a string.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    public func send(
        string message: some StringProtocol,
        to subscriber: some SubscriberProtocol,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high
    ) async throws {
        try await routeMessage(
            message: .string(String(message)),
            to: subscriber,
            expiration: expiration,
            urgency: urgency
        )
    }
    
    /// Send a push message as encoded JSON.
    ///
    /// The service worker you registered is expected to know how to decode the JSON you send. Note that dates are encoded using ``/Foundation/JSONEncoder/DateEncodingStrategy/millisecondsSince1970``, and data is encoded using ``/Foundation/JSONEncoder/DataEncodingStrategy/base64``.
    ///
    /// - Parameters:
    ///   - message: The message to send as JSON.
    ///   - subscriber: The subscriber to send the push message to.
    ///   - expiration: The expiration of the push message, after wich delivery will no longer be attempted.
    ///   - urgency: The urgency of the delivery of the push message.
    public func send(
        json message: some Encodable&Sendable,
        to subscriber: some SubscriberProtocol,
        expiration: Expiration = .recommendedMaximum,
        urgency: Urgency = .high
    ) async throws {
        try await routeMessage(
            message: .json(message),
            to: subscriber,
            expiration: expiration,
            urgency: urgency
        )
    }
    
    /// Route a message to the current executor.
    /// - Parameters:
    ///   - message: The message to send.
    ///   - subscriber: The subscriber to sign the message against.
    ///   - expiration: The expiration of the message.
    ///   - urgency: The urgency of the message.
    func routeMessage(
        message: _Message,
        to subscriber: some SubscriberProtocol,
        expiration: Expiration,
        urgency: Urgency
    ) async throws {
        switch executor {
        case .httpClient(let httpClient):
            try await execute(
                httpClient: httpClient,
                data: message.data,
                subscriber: subscriber,
                expiration: expiration,
                urgency: urgency
            )
        case .handler(let handler):
            try await handler(
                message,
                Subscriber(subscriber),
                expiration,
                urgency
            )
        }
    }
    
    /// Send a message via HTTP Client, mocked or otherwise, encrypting it on the way.
    /// - Parameters:
    ///   - httpClient: The protocol implementing HTTP-like functionality.
    ///   - message: The message to send as raw data.
    ///   - subscriber: The subscriber to sign the message against.
    ///   - expiration: The expiration of the message.
    ///   - urgency: The urgency of the message.
    func execute(
        httpClient: some HTTPClientProtocol,
        data message: some DataProtocol,
        subscriber: some SubscriberProtocol,
        expiration: Expiration,
        urgency: Urgency
    ) async throws {
        guard let signingKey = vapidKeyLookup[subscriber.vapidKeyID]
        else {
            logger.warning("A key was not found for this subscriber.", metadata: [
                "vapidKeyID": "\(subscriber.vapidKeyID)"
            ])
            throw VAPID.ConfigurationError.matchingKeyNotFound
        }
        
        /// Prepare authorization, private keys, and payload ahead of time to bail early if they can't be created.
        let authorization = try loadCurrentVAPIDAuthorizationHeader(endpoint: subscriber.endpoint, signingKey: signingKey)
        let applicationServerECDHPrivateKey = P256.KeyAgreement.PrivateKey()
        
        /// Perform key exchange between the user agent's public key and our private key, deriving a shared secret.
        let userAgent = subscriber.userAgentKeyMaterial
        guard let sharedSecret = try? applicationServerECDHPrivateKey.sharedSecretFromKeyAgreement(with: userAgent.publicKey)
        else { throw BadSubscriberError() }
        
        /// Generate a 16-byte salt.
        var salt: [UInt8] = Array(repeating: 0, count: 16)
        for index in salt.indices { salt[index] = .random(in: .min ... .max) }
        
        if message.count > Self.maximumMessageSize {
            logger.warning("Push message is longer than the maximum guarantee made by the spec: \(Self.maximumMessageSize) bytes. Sending this message may fail, and its size will be leaked despite being encrypted. Please consider sending less data to keep your communications secure.", metadata: ["message": "\(message)"])
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
        
        /// Encrypt the padded payload into a single record https://datatracker.ietf.org/doc/html/rfc8188
        let encryptedRecord = try AES.GCM.seal(paddedPayload, using: contentEncryptionKey, nonce: nonce)
        
        /// Attach the header with our public key and salt, along with the authentication tag.
        let requestContent = contentCodingHeader + encryptedRecord.ciphertext + encryptedRecord.tag
        
        if expiration < Expiration.dropIfUndeliverable {
            logger.error("The message expiration must be greater than or equal to \(Expiration.dropIfUndeliverable) seconds.", metadata: ["expiration": "\(expiration)"])
        } else if expiration >= Expiration.recommendedMaximum {
            logger.warning("The message expiration should be less than \(Expiration.recommendedMaximum) seconds.", metadata: ["expiration": "\(expiration)"])
        }
        
        /// Add the VAPID authorization and corrent content encoding and type.
        var request = HTTPClientRequest(url: subscriber.endpoint.absoluteURL.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: authorization)
        request.headers.add(name: "Content-Encoding", value: "aes128gcm")
        request.headers.add(name: "Content-Type", value: "application/octet-stream")
        request.headers.add(name: "TTL", value: "\(max(expiration, .dropIfUndeliverable).seconds)")
        request.headers.add(name: "Urgency", value: "\(urgency)")
        request.body = .bytes(ByteBuffer(bytes: requestContent))
        
        /// Send the request to the push endpoint.
        let response = try await httpClient.execute(request, deadline: .now() + .seconds(2), logger: logger)
        
        /// Check the response and determine if the subscription should be removed from our records, or if the notification should just be skipped.
        switch response.status {
        case .created: break
        case .notFound, .gone: throw BadSubscriberError()
        // TODO: 413 payload too large - warn and throw error
        // TODO: 429 too many requests, 500 internal server error, 503 server shutting down - check config and perform a retry after a delay?
        default: throw HTTPError(response: response)
        }
        logger.trace("Sent \(message) notification to \(subscriber): \(response)")
    }
}

extension WebPushManager: Service {
    public func run() async throws {
        logger.info("Starting up WebPushManager")
        try await withTaskCancellationOrGracefulShutdownHandler {
            try await gracefulShutdown()
        } onCancelOrGracefulShutdown: { [logger, executor] in
            logger.info("Shutting down WebPushManager")
            do {
                if case let .httpClient(httpClient) = executor {
                    try httpClient.syncShutdown()
                }
            } catch {
                logger.error("Graceful Shutdown Failed", metadata: [
                    "error": "\(error)"
                ])
            }
        }
    }
}

// MARK: - Public Types

extension WebPushManager {
    /// A duration in seconds used to express when push messages will expire.
    ///
    /// - SeeAlso: [RFC 8030 Generic Event Delivery Using HTTP §5.2. Push Message Time-To-Live](https://datatracker.ietf.org/doc/html/rfc8030#section-5.2)
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
        /// - SeeAlso: [RFC 8030 Generic Event Delivery Using HTTP §5.2. Push Message Time-To-Live](https://datatracker.ietf.org/doc/html/rfc8030#section-5.2)
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
    public struct Urgency: Hashable, Comparable, Sendable, CustomStringConvertible {
        let rawValue: String
        
        public static let veryLow = Self(rawValue: "very-low")
        public static let low = Self(rawValue: "low")
        public static let normal = Self(rawValue: "normal")
        public static let high = Self(rawValue: "high")
        
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

// MARK: - Package Types

extension WebPushManager {
    public enum _Message: Sendable {
        case data(Data)
        case string(String)
        case json(any Encodable&Sendable)
        
        var data: Data {
            get throws {
                switch self {
                case .data(let data):
                    return data
                case .string(let string):
                    var string = string
                    return string.withUTF8 { Data($0) }
                case .json(let json):
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .millisecondsSince1970
                    return try encoder.encode(json)
                }
            }
        }
    }
    
    package enum Executor: Sendable {
        case httpClient(any HTTPClientProtocol)
        case handler(@Sendable (
            _ message: _Message,
            _ subscriber: Subscriber,
            _ expiration: Expiration,
            _ urgency: Urgency
        ) async throws -> Void)
    }
}

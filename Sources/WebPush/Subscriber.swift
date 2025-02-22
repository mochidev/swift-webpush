//
//  Subscriber.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-10.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Represents a subscriber registration from the browser.
///
/// Prefer to use ``Subscriber`` directly when possible.
///
/// - SeeAlso: [Push API Working Draft §8. `PushSubscription` interface](https://www.w3.org/TR/push-api/#pushsubscription-interface). Note that the VAPID Key ID must be manually added to the structure supplied by the spec.
public protocol SubscriberProtocol: Sendable {
    /// The endpoint representing the subscriber on their push registration service of choice.
    var endpoint: URL { get }
    
    /// The key material supplied by the user agent.
    var userAgentKeyMaterial: UserAgentKeyMaterial { get }
    
    /// The preferred VAPID Key ID to use, if available.
    ///
    /// If unknown, use the key set to ``VAPID/Configuration/primaryKey``, but be aware that this may be different from the key originally used at time of subscription, and if it is, push messages will be rejected.
    ///
    /// - Important: It is highly recommended to store the VAPID Key ID used at time of registration with the subscriber, and always supply the key itself to the manager. If you are phasing out the key and don't want new subscribers registered against it, store the key in ``VAPID/Configuration/deprecatedKeys``, otherwise store it in ``VAPID/Configuration/keys``.
    var vapidKeyID: VAPID.Key.ID { get }
}

/// The set of cryptographic secrets shared by the browser (is. user agent) along with a subscription.
/// 
/// - SeeAlso: [RFC 8291 — Message Encryption for Web Push §2.1. Key and Secret Distribution](https://datatracker.ietf.org/doc/html/rfc8291#section-2.1)
public struct UserAgentKeyMaterial: Sendable {
    /// The underlying type of an authentication secret.
    public typealias Salt = Data
    
    /// The public key a shared secret can be derived from for message encryption.
    ///
    /// - SeeAlso: [Push API Working Draft §8.1. `PushEncryptionKeyName` enumeration — `p256dh`](https://www.w3.org/TR/push-api/#dom-pushencryptionkeyname-p256dh)
    public var publicKey: P256.KeyAgreement.PublicKey
    
    /// The authentication secret to validate our ability to send a subscriber push messages.
    ///
    /// - SeeAlso: [Push API Working Draft §8.1. `PushEncryptionKeyName` enumeration — `auth`](https://www.w3.org/TR/push-api/#dom-pushencryptionkeyname-auth)
    public var authenticationSecret: Salt
    
    /// Initialize key material with a public key and authentication secret from a user agent.
    ///
    /// - Parameters:
    ///   - publicKey: The public key a shared secret can be derived from for message encryption.
    ///   - authenticationSecret: The authentication secret to validate our ability to send a subscriber push messages.
    public init(
        publicKey: P256.KeyAgreement.PublicKey,
        authenticationSecret: Salt
    ) {
        self.publicKey = publicKey
        self.authenticationSecret = authenticationSecret
    }
    
    /// Initialize key material with a public key and authentication secret from a user agent.
    ///
    /// - Parameters:
    ///   - publicKey: The public key a shared secret can be derived from for message encryption.
    ///   - authenticationSecret: The authentication secret to validate our ability to send a subscriber push messages.
    public init(
        publicKey: String,
        authenticationSecret: String
    ) throws(UserAgentKeyMaterialError) {
        guard let publicKeyData = Data(base64URLEncoded: publicKey)
        else { throw .invalidPublicKey(underlyingError: Base64URLDecodingError()) }
        do {
            self.publicKey = try P256.KeyAgreement.PublicKey(x963Representation: publicKeyData)
        } catch { throw .invalidPublicKey(underlyingError: error) }
        
        guard let authenticationSecretData = Data(base64URLEncoded: authenticationSecret)
        else { throw .invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()) }
        
        self.authenticationSecret = authenticationSecretData
    }
}

extension UserAgentKeyMaterial: Hashable {
    public static func == (lhs: UserAgentKeyMaterial, rhs: UserAgentKeyMaterial) -> Bool {
        lhs.publicKey.x963Representation == rhs.publicKey.x963Representation
        && lhs.authenticationSecret == rhs.authenticationSecret
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(publicKey.x963Representation)
        hasher.combine(authenticationSecret)
    }
}

extension UserAgentKeyMaterial: Codable {
    /// The encoded representation of a subscriber's key material.
    ///
    /// - SeeAlso: [Push API Working Draft §8.1. `PushEncryptionKeyName` enumeration](https://www.w3.org/TR/push-api/#pushencryptionkeyname-enumeration)
    public enum CodingKeys: String, CodingKey {
        case publicKey = "p256dh"
        case authenticationSecret = "auth"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let publicKeyString = try container.decode(String.self, forKey: .publicKey)
        let authenticationSecretString = try container.decode(String.self, forKey: .authenticationSecret)
        try self.init(publicKey: publicKeyString, authenticationSecret: authenticationSecretString)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(publicKey.x963Representation.base64URLEncodedString(), forKey: .publicKey)
        try container.encode(authenticationSecret.base64URLEncodedString(), forKey: .authenticationSecret)
    }
}

/// A default subscriber implementation that can be used to decode subscriptions encoded by client-side JavaScript directly.
///
/// Note that this object requires the VAPID key (`applicationServerKey` in JavaScript) that was supplied during registration, which is not provided by default by [`PushSubscription.toJSON()`](https://www.w3.org/TR/push-api/#dom-pushsubscription-tojson):
/// ```js
/// const subscriptionStatusResponse = await fetch(`/registerSubscription`, {
///     method: "POST",
///     body: {
///         ...subscription.toJSON(),
///         applicationServerKey: subscription.options.applicationServerKey,
///     }
/// });
/// ```
///
/// If you cannot provide this for whatever reason, opt to decode the object using your own type, and conform to ``SubscriberProtocol`` instead.
public struct Subscriber: SubscriberProtocol, Codable, Hashable, Sendable {
    /// The encoded representation of a subscriber.
    ///
    /// - Note: The VAPID Key ID must be manually added to the structure supplied by the spec.
    /// - SeeAlso: [Push API Working Draft §8. `PushSubscription` interface](https://www.w3.org/TR/push-api/#pushsubscription-interface).
    public enum CodingKeys: String, CodingKey {
        case endpoint = "endpoint"
        case userAgentKeyMaterial = "keys"
        case vapidKeyID = "applicationServerKey"
    }
    
    /// The push endpoint associated with the push subscription.
    ///
    /// - SeeAlso: [Push API Working Draft §8. `PushSubscription` interface — `endpoint`](https://www.w3.org/TR/push-api/#dfn-getting-the-endpoint-attribute)
    public var endpoint: URL
    
    /// The key material provided by the user agent to encrupt push data with.
    ///
    /// - SeeAlso: [Push API Working Draft §8. `PushSubscription` interface — `getKey`](https://www.w3.org/TR/push-api/#dom-pushsubscription-getkey)
    public var userAgentKeyMaterial: UserAgentKeyMaterial
    
    /// The VAPID Key ID used to register the subscription, that identifies the application server with the push service.
    ///
    /// - SeeAlso: [Push API Working Draft §8. `PushSubscription` interface — `options`](https://www.w3.org/TR/push-api/#dom-pushsubscription-options)
    public var vapidKeyID: VAPID.Key.ID
    
    /// Initialize a new subscriber manually.
    ///
    /// Prefer decoding a subscription directly with the results of the subscription directly:
    /// ```js
    /// const subscriptionStatusResponse = await fetch(`/registerSubscription`, {
    ///     method: "POST",
    ///     body: {
    ///         ...subscription.toJSON(),
    ///         applicationServerKey: subscription.options.applicationServerKey,
    ///     }
    /// });
    /// ```
    public init(
        endpoint: URL,
        userAgentKeyMaterial: UserAgentKeyMaterial,
        vapidKeyID: VAPID.Key.ID
    ) {
        self.endpoint = endpoint
        self.userAgentKeyMaterial = userAgentKeyMaterial
        self.vapidKeyID = vapidKeyID
    }
    
    /// Cast an object that conforms to ``SubscriberProtocol`` to a ``Subscriber``.
    public init(_ subscriber: some SubscriberProtocol) {
        self.init(
            endpoint: subscriber.endpoint,
            userAgentKeyMaterial: subscriber.userAgentKeyMaterial,
            vapidKeyID: subscriber.vapidKeyID
        )
    }
}

extension Subscriber: Identifiable {
    /// A safe identifier to use for the subscriber without exposing key material.
    public var id: String { endpoint.absoluteString }
}

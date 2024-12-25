//
//  Topic.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-24.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
import Foundation

/// Topics are used to de-duplicate and overwrite messages on push services before they are delivered to a subscriber.
///
/// The topic is never delivered to your service worker, though is seen in plain text by the Push Service, so this type encodes it first to prevent leaking any information about the messages you are sending or your subscribers.
///
/// - Important: Since topics are sent in the clear to push services, they must be securely hashed. You must use a stable random value for this, such as the subscriber's ``UserAgentKeyMaterial/authenticationSecret``. This is fine for most applications, though you may wish to use a different key if your application requires it.
///
/// - SeeAlso: [RFC 8030 — Generic Event Delivery Using HTTP §5.4. Replacing Push Messages](https://datatracker.ietf.org/doc/html/rfc8030#section-5.4)
public struct Topic: Hashable, Sendable, CustomStringConvertible {
    /// The topic value to use.
    public let topic: String
    
    /// Create a new topic from encodable data and a salt.
    /// 
    /// - Important: Since topics are sent in the clear to push services, they must be securely hashed. You must use a stable random value for this, such as the subscriber's ``UserAgentKeyMaterial/authenticationSecret``. This is fine for most applications, though you may wish to use a different key if your application requires it.
    ///
    /// - Parameters:
    ///   - encodableTopic: The encodable data that represents a stable topic. This can be a string, identifier, or any other token that can be encoded.
    ///   - salt: The salt that should be used when encoding the topic.
    public init(
        encodableTopic: some Encodable,
        salt: some DataProtocol
    ) throws {
        /// First, turn the topic into a byte stream.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedTopic = try encoder.encode(encodableTopic)
        
        /// Next, hash the topic using the provided salt, some info, and cut to length at 24 bytes.
        let hashedTopic = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: encodedTopic),
            salt: salt,
            info: "WebPush Topic".utf8Bytes,
            outputByteCount: 24
        )
        
        /// Transform these 24 bytes into 32 Base64 URL-safe characters.
        self.topic = hashedTopic.base64URLEncodedString()
    }
    
    /// Create a new random topic.
    ///
    /// Create a topic with a random identifier to save it in your own data stores, and re-use it as needed.
    public init() {
        /// Generate a 24-byte topic.
        var topicBytes: [UInt8] = Array(repeating: 0, count: 24)
        for index in topicBytes.indices { topicBytes[index] = .random(in: .min ... .max) }
        self.topic = topicBytes.base64URLEncodedString()
    }
    
    /// Initialize a topic with an unchecked string.
    ///
    /// Prefer to use ``init(encodableTopic:salt:)`` when possible.
    ///
    /// - Warning: This may be rejected by a Push Service if it is not 32 Base64 URL-safe characters, and will not be encrypted. Expect to handle a ``PushServiceError`` with a ``PushServiceError/response`` status code of `400 Bad Request` when it does.
    public init(unsafeTopic: String) {
        topic = unsafeTopic
    }
    
    public var description: String {
        topic
    }
}

extension Topic: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        topic = try container.decode(String.self)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(topic)
    }
}

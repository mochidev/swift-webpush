//
//  VAPIDKey.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-04.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension VoluntaryApplicationServerIdentification {
    /// Represents the application server's identification key that is used to confirm to a push service that the server connecting to it is the same one that was subscribed to.
    ///
    /// When sharing with the browser, ``VAPID/Key/ID`` can be used.
    public struct Key: Sendable {
        private var privateKey: P256.Signing.PrivateKey
        
        /// Create a brand new VAPID signing key.
        ///
        /// - Note: You must persist this key somehow if you are creating it yourself.
        public init() {
            privateKey = P256.Signing.PrivateKey(compactRepresentable: false)
        }
        
        /// Initialize a key from a P256 SIgning Private Key.
        ///
        /// - Warning: Do not re-use this key for any other purpose other than VAPID authorization!
        public init(privateKey: P256.Signing.PrivateKey) {
            self.privateKey = privateKey
        }
        
        /// Decode a key directly from a Base 64 (URL) encoded string, or throw an error if decoding failed.
        public init(base64URLEncoded: String) throws {
            guard let data = Data(base64URLEncoded: base64URLEncoded)
            else { throw Base64URLDecodingError() }
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: data)
        }
    }
}

extension VAPID.Key: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.privateKey.rawRepresentation == rhs.privateKey.rawRepresentation
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(privateKey.rawRepresentation)
    }
}

extension VAPID.Key: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        privateKey = try P256.Signing.PrivateKey(rawRepresentation: container.decode(Data.self))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(privateKey.rawRepresentation)
    }
}

extension VAPID.Key: Identifiable {
    /// The identifier for a private ``VAPID/Key``'s public key.
    ///
    /// This value can be shared as is with a subscription registration as the `applicationServerKey` key in JavaScript.
    ///
    /// - SeeAlso: [Push API Working Draft §7.2. `PushSubscriptionOptions` Interface](https://www.w3.org/TR/push-api/#pushsubscriptionoptions-interface)
    public struct ID: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
        /// The raw string that represents the ID.
        private var rawValue: String
        
        /// Initialize an ID with a raw string.
        init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.rawValue = try container.decode(String.self)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        public var description: String {
            self.rawValue
        }
    }
    
    /// The public key component in a format suitable for user agents to consume.
    ///
    /// - SeeAlso: [Push API Working Draft §7.2. `PushSubscriptionOptions` Interface](https://www.w3.org/TR/push-api/#dom-pushsubscriptionoptions-applicationserverkey)
    /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §3.2. Public Key Parameter ("k")](https://datatracker.ietf.org/doc/html/rfc8292#section-3.2)
    public var id: ID {
        ID(privateKey.publicKey.x963Representation.base64URLEncodedString())
    }
}

extension VAPID.Key: VAPIDKeyProtocol {
    func signature(for message: some DataProtocol) throws -> P256.Signing.ECDSASignature {
        try privateKey.signature(for: SHA256.hash(data: message))
    }
}

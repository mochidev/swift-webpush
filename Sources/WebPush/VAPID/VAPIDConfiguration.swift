//
//  VAPIDConfiguration.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-04.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

extension VoluntaryApplicationServerIdentification {
    public struct Configuration: Hashable, Sendable {
        /// The VAPID key that identifies the push service to subscribers.
        ///
        /// This key should be shared by all instances of your push service, and should be kept secure. Rotating this key is not recommended as you'll lose access to subscribers that registered against it.
        ///
        /// Some implementations will choose to use different keys per subscriber. In that case, choose to provide a set of keys instead.
        public private(set) var primaryKey: Key?
        public private(set) var keys: Set<Key>
        public private(set) var deprecatedKeys: Set<Key>?
        public var contactInformation: ContactInformation
        public var expirationDuration: Duration
        public var validityDuration: Duration
        
        public init(
            key: Key,
            deprecatedKeys: Set<Key>? = nil,
            contactInformation: ContactInformation,
            expirationDuration: Duration = .hours(22),
            validityDuration: Duration = .hours(20)
        ) {
            self.primaryKey = key
            self.keys = [key]
            var deprecatedKeys = deprecatedKeys ?? []
            deprecatedKeys.remove(key)
            self.deprecatedKeys = deprecatedKeys.isEmpty ? nil : deprecatedKeys
            self.contactInformation = contactInformation
            self.expirationDuration = expirationDuration
            self.validityDuration = validityDuration
        }
        
        public init(
            primaryKey: Key?,
            keys: Set<Key>,
            deprecatedKeys: Set<Key>? = nil,
            contactInformation: ContactInformation,
            expirationDuration: Duration = .hours(22),
            validityDuration: Duration = .hours(20)
        ) throws(ConfigurationError) {
            self.primaryKey = primaryKey
            var keys = keys
            if let primaryKey {
                keys.insert(primaryKey)
            }
            guard !keys.isEmpty
            else { throw .keysNotProvided }
            
            self.keys = keys
            var deprecatedKeys = deprecatedKeys ?? []
            deprecatedKeys.subtract(keys)
            self.deprecatedKeys = deprecatedKeys.isEmpty ? nil : deprecatedKeys
            self.contactInformation = contactInformation
            self.expirationDuration = expirationDuration
            self.validityDuration = validityDuration
        }
        
        mutating func updateKeys(
            primaryKey: Key?,
            keys: Set<Key>,
            deprecatedKeys: Set<Key>? = nil
        ) throws(ConfigurationError) {
            self.primaryKey = primaryKey
            var keys = keys
            if let primaryKey {
                keys.insert(primaryKey)
            }
            guard !keys.isEmpty
            else { throw .keysNotProvided }
            
            self.keys = keys
            var deprecatedKeys = deprecatedKeys ?? []
            deprecatedKeys.subtract(keys)
            self.deprecatedKeys = deprecatedKeys.isEmpty ? nil : deprecatedKeys
        }
    }
}

extension VAPID.Configuration: Codable {
    public enum CodingKeys: CodingKey {
        case primaryKey
        case keys
        case deprecatedKeys
        case contactInformation
        case expirationDuration
        case validityDuration
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let primaryKey = try container.decodeIfPresent(VAPID.Key.self, forKey: CodingKeys.primaryKey)
        let keys = try container.decodeIfPresent(Set<VAPID.Key>.self, forKey: CodingKeys.keys) ?? []
        let deprecatedKeys = try container.decodeIfPresent(Set<VAPID.Key>.self, forKey: CodingKeys.deprecatedKeys)
        let contactInformation = try container.decode(ContactInformation.self, forKey: CodingKeys.contactInformation)
        let expirationDuration = try container.decode(Duration.self, forKey: CodingKeys.expirationDuration)
        let validityDuration = try container.decode(Duration.self, forKey: CodingKeys.validityDuration)
        
        try self.init(
            primaryKey: primaryKey,
            keys: keys,
            deprecatedKeys: deprecatedKeys,
            contactInformation: contactInformation,
            expirationDuration: expirationDuration,
            validityDuration: validityDuration
        )
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        /// Remove the primary key from the list so it's not listed twice
        var keys: Set<VAPID.Key>? = self.keys
        if let primaryKey {
            keys?.remove(primaryKey)
        }
        if keys?.isEmpty == true {
            keys = nil
        }
        
        try container.encodeIfPresent(primaryKey, forKey: .primaryKey)
        try container.encodeIfPresent(keys, forKey: .keys)
        try container.encodeIfPresent(deprecatedKeys, forKey: .deprecatedKeys)
        try container.encode(contactInformation, forKey: .contactInformation)
        try container.encode(expirationDuration, forKey: .expirationDuration)
        try container.encode(validityDuration, forKey: .validityDuration)
    }
}

extension VAPID.Configuration {
    /// The contact information for the push service.
    ///
    /// This allows administrators of push services to contact you should an issue arise with your application server.
    ///
    /// - Note: Although the specification notes that this field is optional, some push services may refuse connection from serers without contact information.
    /// - SeeAlso: [RFC8292 Voluntary Application Server Identification (VAPID) for Web Push §2.1. Application Server Contact Information](https://datatracker.ietf.org/doc/html/rfc8292#section-2.1)
    public enum ContactInformation: Hashable, Codable, Sendable {
        /// A URL-based contact method, such as a support page on your website.
        case url(URL)
        /// An email-based contact method.
        case email(String)
        
        var urlString: String {
            switch self {
            case .url(let url):     url.absoluteURL.absoluteString
            case .email(let email): "mailto:\(email)"
            }
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let url = try container.decode(URL.self)
            
            switch url.scheme?.lowercased() {
            case "mailto":
                let email = String(url.absoluteString.dropFirst("mailto:".count))
                if !email.isEmpty {
                    self = .email(email)
                } else {
                    throw DecodingError.typeMismatch(URL.self, .init(codingPath: decoder.codingPath, debugDescription: "Found a mailto URL with no email."))
                }
            case "http", "https":
                self = .url(url)
            default:
                throw DecodingError.typeMismatch(URL.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected a mailto or http(s) URL, but found neither."))
            }
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(urlString)
        }
    }
    
    /// The satus of a key as it relates to a configuration.
    ///
    /// - SeeAlso: ``WebPushManager/keyStatus(for:)``
    public enum KeyStatus: Sendable, Hashable {
        /// The key is valid and should continue to be used.
        case valid
        
        /// The key had been deprecated.
        ///
        /// The user should be encouraged to re-register using a new key.
        case deprecated
        
        /// The key is unknown to the configuration.
        ///
        /// The configuration should be investigated as all keys should be accounted for.
        case unknown
    }
    
    public struct Duration: Hashable, Comparable, Codable, ExpressibleByIntegerLiteral, AdditiveArithmetic, Sendable {
        public let seconds: Int
        
        public init(seconds: Int) {
            self.seconds = seconds
        }
        
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
        
        public init(integerLiteral value: Int) {
            self.seconds = value
        }
        
        public static func - (lhs: Self, rhs: Self) -> Self {
            Self(seconds: lhs.seconds - rhs.seconds)
        }
        
        public static func + (lhs: Self, rhs: Self) -> Self {
            Self(seconds: lhs.seconds + rhs.seconds)
        }
        
        public static func seconds(_ seconds: Int) -> Self {
            Self(seconds: seconds)
        }
        
        public static func minutes(_ minutes: Int) -> Self {
            Self(seconds: minutes*60)
        }
        
        public static func hours(_ hours: Int) -> Self {
            Self(seconds: hours*60*60)
        }
        
        public static func days(_ days: Int) -> Self {
            Self(seconds: days*24*60*60)
        }
    }
}

extension Date {
    func adding(_ duration: VAPID.Configuration.Duration) -> Self {
        addingTimeInterval(TimeInterval(duration.seconds))
    }
}

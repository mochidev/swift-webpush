//
//  VAPIDConfiguration.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-04.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension VoluntaryApplicationServerIdentification {
    /// A configuration object specifying the contact information along with the keys that your application server identifies itself with.
    ///
    /// The ``primaryKey``, when priovided, will always be used for new subscriptions when ``WebPushManager/nextVAPIDKeyID`` is called. If omitted, one of the keys in ``keys`` will be randomely chosen instead.
    ///
    /// ``deprecatedKeys`` that you must stull support for older subscribers, but don't wish to use when registering new subscribers, may also be specified.
    ///
    /// To reduce implementation complexity, it is recommended to only use a single ``primaryKey``, though this key should be stored with subscribers as ``Subscriber`` encourages you to do so that you can deprecate it in the future should it ever leak.
    ///
    /// ## Codable
    ///
    /// VAPID configurations should ideally be generated a single time and shared across all instances of your application server, across runs. To facilitate this, you can encode and decode a configuration to load it at runtime rather than instanciate a new one every time:
    /// ```swift
    /// // TODO: Load this data from .env or from file system
    /// let configurationData = Data(#" {"contactInformation":"https://example.com","expirationDuration":79200,"primaryKey":"6PSSAJiMj7uOvtE4ymNo5GWcZbT226c5KlV6c+8fx5g=","validityDuration":72000} "#.utf8)
    /// let vapidConfiguration = try JSONDecoder().decode(VAPID.Configuration.self, from: configurationData)
    /// ```
    ///
    /// - SeeAlso: [Generating Keys](https://github.com/mochidev/swift-webpush?tab=readme-ov-file#generating-keys): Keys can also be generated by our `vapid-key-generator` helper tool.
    public struct Configuration: Hashable, Sendable {
        /// The VAPID key that identifies the push service to subscribers.
        ///
        /// If not provided, a key from ``keys`` will be used instead.
        /// - SeeAlso: ``VAPID/Configuration``
        public private(set) var primaryKey: Key?
        
        /// The set of valid keys to choose from when identifying the applications erver to new registrations.
        public private(set) var keys: Set<Key>
        
        /// The set of deprecated keys to continue to support when signing push messages, but shouldn't be used for new registrations.
        ///
        /// This set can be interogated via ``WebPushManager/`` to determine if a subscriber should be re-registered against a new key or not:
        /// ```swift
        /// webPushManager.keyStatus(for: subscriber.vapidKeyID) == .deprecated
        /// ```
        public private(set) var deprecatedKeys: Set<Key>?
        
        /// The contact information an administrator of a push service may use to contact you in the case of an issue.
        public var contactInformation: ContactInformation
        
        /// The number of seconds before a cached authentication header signed by this configuration fully expires.
        ///
        /// This value must be 24 hours or less, and it conservatively set to 22 hours by default to account for clock drift between your applications erver and push services.
        public var expirationDuration: Duration
        
        /// The number of seconds before a cached authentication header signed by this configuration is renewed.
        ///
        /// This valus must be less than ``expirationDuration``, and is set to 20 hours by default as an adequate compromise between re-usability and key over-use.
        public var validityDuration: Duration
        
        /// Initialize a configuration with a single primary key.
        /// - Parameters:
        ///   - key: The primary key to use when introducing your application server during registration.
        ///   - deprecatedKeys: Suppoted, but deprecated, keys to use during push delivery if a subscriber requires them.
        ///   - contactInformation: The contact information an administrator of a push service may use to contact you in the case of an issue.
        ///   - expirationDuration: The number of seconds before a cached authentication header signed by this configuration fully expires.
        ///   - validityDuration: The number of seconds before a cached authentication header signed by this configuration is renewed.
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
        
        /// Initialize a configuration with a multiple VAPID keys.
        ///
        /// Use this initializer _only_ if you wish to implement more complicated key rotation if you believe keys may be leaked at a higher rate than usual. In all other cases, it is highly recommended to use ``init(key:deprecatedKeys:contactInformation:expirationDuration:validityDuration:)`` instead to supply a singly primary key and keep it secure.
        /// - Parameters:
        ///   - primaryKey: The optional primary key to use when introducing your application server during registration.
        ///   - keys: The set of valid keys to choose from when identifying the applications erver to new registrations.
        ///   - deprecatedKeys: Suppoted, but deprecated, keys to use during push delivery if a subscriber requires them.
        ///   - contactInformation: The contact information an administrator of a push service may use to contact you in the case of an issue.
        ///   - expirationDuration: The number of seconds before a cached authentication header signed by this configuration fully expires.
        ///   - validityDuration: The number of seconds before a cached authentication header signed by this configuration is renewed.
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
        
        /// Update the keys that this configuration represents.
        /// 
        /// At least one non-deprecated key must be specified, whether it is a primary key or specified in the list of keys, or this method will throw.
        /// - Parameters:
        ///   - primaryKey: The primary key to use when registering a new subscriber.
        ///   - keys: A list of valid, non deprecated keys to cycle through if a primary key is not specified.
        ///   - deprecatedKeys: A list of deprecated keys to use for signing if a subscriber requires it, but won't be used for new registrations.
        public mutating func updateKeys(
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
        
        /// Internal method to set invalid state for validation that other components are resiliant to these configurations.
        mutating func unsafeUpdateKeys(
            primaryKey: Key? = nil,
            keys: Set<Key>,
            deprecatedKeys: Set<Key>? = nil
        ) {
            self.primaryKey = primaryKey
            self.keys = keys
            self.deprecatedKeys = deprecatedKeys
        }
    }
}

extension VAPID.Configuration: Codable {
    /// The coding keys used to encode a VAPID configuration.
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
    /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2.1. Application Server Contact Information](https://datatracker.ietf.org/doc/html/rfc8292#section-2.1)
    public enum ContactInformation: Hashable, Codable, Sendable {
        /// A URL-based contact method, such as a support page on your website.
        case url(URL)
        /// An email-based contact method.
        case email(String)
        
        /// The string that representa the contact information as a fully-qualified URL.
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
    
    /// A duration in seconds used to express when VAPID tokens will expire.
    public struct Duration: Hashable, Comparable, Codable, ExpressibleByIntegerLiteral, AdditiveArithmetic, Sendable {
        /// The number of seconds represented by this duration.
        public let seconds: Int
        
        /// Initialize a duration with a number of seconds.
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
        
        /// Make a duration with a number of seconds.
        @inlinable
        public static func seconds(_ seconds: Int) -> Self {
            Self(seconds: seconds)
        }
        
        /// Make a duration with a number of minutes.
        @inlinable
        public static func minutes(_ minutes: Int) -> Self {
            .seconds(minutes*60)
        }
        
        /// Make a duration with a number of hours.
        @inlinable
        public static func hours(_ hours: Int) -> Self {
            .minutes(hours*60)
        }
        
        /// Make a duration with a number of days.
        @inlinable
        public static func days(_ days: Int) -> Self {
            .hours(days*24)
        }
    }
}

extension Date {
    /// Helper to add a duration to a date.
    func adding(_ duration: VAPID.Configuration.Duration) -> Self {
        addingTimeInterval(TimeInterval(duration.seconds))
    }
}

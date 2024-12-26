//
//  UserAgentKeyMaterialError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An error encountered during ``VAPID/Configuration`` initialization or decoding.
public struct UserAgentKeyMaterialError: LocalizedError, Sendable {
    /// The kind of error that occured.
    enum Kind {
        /// The public key was invalid.
        case invalidPublicKey
        /// The authentication secret was invalid.
        case invalidAuthenticationSecret
    }
    
    /// The kind of error that occured.
    var kind: Kind
    
    /// The underlying error that caused this one.
    public var underlyingError: any Error
    
    /// The public key was invalid.
    public static func invalidPublicKey(underlyingError: Error) -> Self {
        Self(kind: .invalidPublicKey, underlyingError: underlyingError)
    }
    
    /// The authentication secret was invalid.
    public static func invalidAuthenticationSecret(underlyingError: Error) -> Self {
        Self(kind: .invalidAuthenticationSecret, underlyingError: underlyingError)
    }
    
    public var errorDescription: String? {
        switch kind {
        case .invalidPublicKey:
            "Subscriber Public Key (`\(UserAgentKeyMaterial.CodingKeys.publicKey.stringValue)`) was invalid: \(underlyingError.localizedDescription)"
        case .invalidAuthenticationSecret:
            "Subscriber Authentication Secret (`\(UserAgentKeyMaterial.CodingKeys.authenticationSecret.stringValue)`) was invalid: \(underlyingError.localizedDescription)"
        }
    }
}

extension UserAgentKeyMaterialError: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.kind == rhs.kind && lhs.underlyingError.localizedDescription == rhs.underlyingError.localizedDescription
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(underlyingError.localizedDescription)
    }
}

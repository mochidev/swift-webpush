//
//  UserAgentKeyMaterialError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

/// An error encountered during ``VAPID/Configuration`` initialization or decoding.
public struct UserAgentKeyMaterialError: LocalizedError {
    enum Kind {
        case invalidPublicKey
        case invalidAuthenticationSecret
    }
    
    var kind: Kind
    var underlyingError: any Error
    
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
            "Subscriber Public Key (`\(UserAgentKeyMaterial.CodingKeys.publicKey)`) was invalid: \(underlyingError.localizedDescription)."
        case .invalidAuthenticationSecret:
            "Subscriber Authentication Secret (`\(UserAgentKeyMaterial.CodingKeys.authenticationSecret)`) was invalid: \(underlyingError.localizedDescription)."
        }
    }
}

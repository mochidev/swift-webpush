//
//  Base64URLDecodingError.swift
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

/// An error encountered while decoding Base64 data.
public struct Base64URLDecodingError: LocalizedError, Hashable, Sendable {
    /// Create a new base 64 decoding error.
    public init() {}
    
    public var errorDescription: String? {
        "The Base64 data could not be decoded."
    }
}

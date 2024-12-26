//
//  BadSubscriberError.swift
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

/// The subscription is no longer valid and should be removed and re-registered.
///
/// - Warning: Do not continue to send notifications to invalid subscriptions or you'll risk being rate limited by push services.
public struct BadSubscriberError: LocalizedError, Hashable, Sendable {
    /// Create a new bad subscriber error.
    public init() {}
    
    public var errorDescription: String? {
        "The subscription is no longer valid."
    }
}

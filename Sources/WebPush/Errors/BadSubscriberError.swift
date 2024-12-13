//
//  BadSubscriberError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

/// The subscription is no longer valid and should be removed and re-registered.
///
/// - Warning: Do not continue to send notifications to invalid subscriptions or you'll risk being rate limited by push services.
public struct BadSubscriberError: LocalizedError, Hashable {
    public init() {}
    
    public var errorDescription: String? {
        "The subscription is no longer valid."
    }
}

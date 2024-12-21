//
//  MessageTooLargeError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

/// The message was too large, and could not be delivered to the push service.
///
/// - SeeAlso: ``WebPushManager/maximumMessageSize``
public struct MessageTooLargeError: LocalizedError, Hashable, Sendable {
    public init() {}
    
    public var errorDescription: String? {
        "The message was too large, and could not be delivered to the push service."
    }
}

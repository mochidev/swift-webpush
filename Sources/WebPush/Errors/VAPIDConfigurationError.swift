//
//  VAPIDConfigurationError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

extension VAPID {
    /// An error encountered during ``VAPID/Configuration`` initialization or decoding.
    public struct ConfigurationError: LocalizedError, Hashable, Sendable {
        /// The kind of error that occured.
        enum Kind {
            /// VAPID keys not found during initialization.
            case keysNotProvided
            /// A VAPID key for the subscriber was not found.
            case matchingKeyNotFound
        }
        
        /// The kind of error that occured.
        var kind: Kind
        
        /// VAPID keys not found during initialization.
        public static let keysNotProvided = Self(kind: .keysNotProvided)
        
        /// A VAPID key for the subscriber was not found.
        public static let matchingKeyNotFound = Self(kind: .matchingKeyNotFound)
        
        public var errorDescription: String? {
            switch kind {
            case .keysNotProvided:
                "VAPID keys not found during initialization."
            case .matchingKeyNotFound:
                "A VAPID key for the subscriber was not found."
            }
        }
    }
}

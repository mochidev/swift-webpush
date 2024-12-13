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
    public struct ConfigurationError: LocalizedError, Hashable {
        enum Kind {
            case keysNotProvided
        }
        
        var kind: Kind
        
        /// VAPID keys not found during initialization.
        public static let keysNotProvided = Self(kind: .keysNotProvided)
        
        public var errorDescription: String? {
            switch kind {
            case .keysNotProvided:
                "VAPID keys not found during initialization."
            }
        }
    }
}

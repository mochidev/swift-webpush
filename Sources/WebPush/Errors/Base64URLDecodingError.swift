//
//  Base64URLDecodingError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

/// An error encountered while decoding Base64 data.
public struct Base64URLDecodingError: LocalizedError, Hashable {
    public init() {}
    
    public var errorDescription: String? {
        "The Base64 data could not be decoded."
    }
}

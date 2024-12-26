//
//  VAPIDConfiguration+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-12.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import WebPush

extension VAPID.Configuration {
    /// A mocked configuration useful when testing with the library, since the mocked manager doesn't make use of it anyways.
    public static let mockedConfiguration = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@example.com"))
}

//
//  VAPIDConfiguration+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-12.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
import Foundation
import WebPush

extension VAPID.Configuration {
    /// A mocked configuration useful when testing with the library, since the mocked manager doesn't make use of it anyways.
    public static let mocked = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@example.com"))
}

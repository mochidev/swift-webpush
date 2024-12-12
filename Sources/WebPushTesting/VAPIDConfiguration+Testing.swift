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
    public static var mocked: Self {
        /// Generated using `P256.Signing.PrivateKey(compactRepresentable: false).x963Representation.base64EncodedString()`.
        let privateKey = try! P256.Signing.PrivateKey(x963Representation: Data(base64Encoded: "BGEhWik09/s/JNkl0OAcTIdRTb7AoLRZQQG4C96OhlcFVQYH5kMWUML3MZBG3gPXxN1Njn6uXulDysPGMDBR47SurTnyXnbuaJ7VDm3UsVYUs5kFoZM8VB5QtoKpgE7WyQ==")!)
        return VAPID.Configuration(
            key: .init(privateKey: privateKey),
            contactInformation: .email("test@example.com")
        )
    }
}

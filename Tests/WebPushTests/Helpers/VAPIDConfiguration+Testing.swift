//
//  VAPIDConfiguration+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-06.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import WebPush

extension VAPID.Configuration {
    /// Make a new configuration useful for testing against.
    static func makeTesting() -> VAPID.Configuration {
        VAPID.Configuration(
            key: VAPID.Key(),
            contactInformation: .url(URL(string: "https://example.com/contact")!)
        )
    }
}

//
//  HTTPError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
import Foundation

/// An unknown HTTP error was encountered.
///
/// - SeeAlso: [RFC8030 Generic Event Delivery Using HTTP Push](https://datatracker.ietf.org/doc/html/rfc8030)
/// - SeeAlso: [RFC8292 Voluntary Application Server Identification (VAPID) for Web Push](https://datatracker.ietf.org/doc/html/rfc8292)
/// - SeeAlso: [Sending web push notifications in web apps and browsers — Review responses for push notification errors](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers#Review-responses-for-push-notification-errors)
public struct HTTPError: LocalizedError {
    let response: HTTPClientResponse
    
    init(response: HTTPClientResponse) {
        self.response = response
    }
    
    public var errorDescription: String? {
        "A \(response.status) HTTP error was encountered: \(response)."
    }
}

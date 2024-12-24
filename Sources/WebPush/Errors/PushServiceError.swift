//
//  PushServiceError.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-13.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
import Foundation

/// An unknown Push Service error was encountered.
///
/// - SeeAlso: [RFC 8030 Generic Event Delivery Using HTTP Push](https://datatracker.ietf.org/doc/html/rfc8030)
/// - SeeAlso: [RFC 8292 Voluntary Application Server Identification (VAPID) for Web Push](https://datatracker.ietf.org/doc/html/rfc8292)
/// - SeeAlso: [Sending web push notifications in web apps and browsers — Review responses for push notification errors](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers#Review-responses-for-push-notification-errors)
public struct PushServiceError: LocalizedError, Sendable {
    /// The HTTP response that was returned from the push service..
    public let response: HTTPClientResponse
    
    /// A cached description from the response that won't change over the lifetime of the error.
    let capturedResponseDescription: String
    
    /// Create a new http error.
    public init(response: HTTPClientResponse) {
        self.response = response
        self.capturedResponseDescription = "\(response)"
    }
    
    public var errorDescription: String? {
        "A \(response.status) Push Service error was encountered: \(capturedResponseDescription)."
    }
}

extension PushServiceError: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        "\(lhs.capturedResponseDescription)" == "\(rhs.capturedResponseDescription)"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine("\(capturedResponseDescription)")
    }
}

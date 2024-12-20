//
//  WebPushManager+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-12.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Logging
import WebPush

extension WebPushManager {
    /// A push message in its original form, either ``/Foundation/Data``, ``/Swift/String``, or ``/Foundation/Encodable``.
    /// - Warning: Never switch on the message type, as values may be added to it over time.
    public typealias Message = _Message
    
    /// Create a mocked web push manager.
    ///
    /// The mocked manager will forward all messages as is to its message handler so that you may either verify that a push was sent, or inspect the contents of the message that was sent.
    ///
    /// - Parameters:
    ///   - vapidConfiguration: A VAPID configuration, though the mocked manager doesn't make use of it.
    ///   - logger: An optional logger.
    ///   - messageHandler: A handler to receive messages or throw errors.
    /// - Returns: A new manager suitable for mocking.
    public static func makeMockedManager(
        vapidConfiguration: VAPID.Configuration = .mockedConfiguration,
        // TODO: Add networkConfiguration for proxy, number of simultaneous pushes, etc…
        backgroundActivityLogger: Logger? = .defaultWebPushPrintLogger,
        messageHandler: @escaping @Sendable (
            _ message: Message,
            _ subscriber: Subscriber,
            _ expiration: Expiration,
            _ urgency: Urgency
        ) async throws -> Void
    ) -> WebPushManager {
        let backgroundActivityLogger = backgroundActivityLogger ?? .defaultWebPushNoOpLogger
        
        return WebPushManager(
            vapidConfiguration: vapidConfiguration,
            backgroundActivityLogger: backgroundActivityLogger,
            executor: .handler(messageHandler)
        )
    }
}

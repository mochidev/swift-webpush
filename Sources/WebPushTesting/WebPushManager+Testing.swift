//
//  WebPushManager+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-12.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Logging
import WebPush
import Synchronization

extension WebPushManager {
    /// A push message in its original form, either ``/Foundation/Data``, ``/Swift/String``, or ``/Foundation/Encodable``.
    /// - Warning: Never switch on the message type, as values may be added to it over time.
    public typealias Message = _Message
    
    public typealias MessageHandler = @Sendable (
        _ message: Message,
        _ subscriber: Subscriber,
        _ topic: Topic?,
        _ expiration: Expiration,
        _ urgency: Urgency
    ) async throws -> Void
    
    /// Create a mocked web push manager.
    ///
    /// The mocked manager will forward all messages as is to its message handler so that you may either verify that a push was sent, or inspect the contents of the message that was sent.
    ///
    /// - SeeAlso: ``makeMockedManager(vapidConfiguration:backgroundActivityLogger:messageHandlers:_:)``
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
        messageHandler: @escaping MessageHandler = { _, _, _, _, _ in }
    ) -> WebPushManager {
        let backgroundActivityLogger = backgroundActivityLogger ?? .defaultWebPushNoOpLogger
        
        return WebPushManager(
            vapidConfiguration: vapidConfiguration,
            backgroundActivityLogger: backgroundActivityLogger,
            executor: .handler(messageHandler)
        )
    }
    
    /// Create a mocked web push manager.
    ///
    /// The mocked manager will forward all messages as is to its message handlers so that you may either verify that a push was sent, or inspect the contents of the message that was sent. Assign multiple handlers here to have each message that comes in rotate through the handlers, looping when they are exausted.
    ///
    /// - Parameters:
    ///   - vapidConfiguration: A VAPID configuration, though the mocked manager doesn't make use of it.
    ///   - logger: An optional logger.
    ///   - messageHandlers: A list of handlers to receive messages or throw errors.
    /// - Returns: A new manager suitable for mocking.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @_disfavoredOverload
    public static func makeMockedManager(
        vapidConfiguration: VAPID.Configuration = .mockedConfiguration,
        // TODO: Add networkConfiguration for proxy, number of simultaneous pushes, etc…
        backgroundActivityLogger: Logger? = .defaultWebPushPrintLogger,
        messageHandlers: @escaping MessageHandler,
        _ otherHandlers: MessageHandler...
    ) -> WebPushManager {
        let backgroundActivityLogger = backgroundActivityLogger ?? .defaultWebPushNoOpLogger
        let index = Mutex(0)
        let allHandlers = [messageHandlers] + otherHandlers
        
        return WebPushManager(
            vapidConfiguration: vapidConfiguration,
            backgroundActivityLogger: backgroundActivityLogger,
            executor: .handler({ message, subscriber, topic, expiration, urgency in
                let currentIndex = index.withLock { index in
                    let current = index
                    index = (index + 1) % allHandlers.count
                    return current
                }
                return try await allHandlers[currentIndex](message, subscriber, topic, expiration, urgency)
            })
        )
    }
}

//
//  WebPushManager.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import ServiceLifecycle

actor WebPushManager: Service, Sendable {
    public let vapidConfiguration: VAPID.Configuration
    
    nonisolated let logger: Logger
    let httpClient: HTTPClient
    
    let vapidKeyLookup: [VAPID.Key.ID : VAPID.Key]
    var vapidAuthorizationCache: [String : (authorization: String, expiration: Date)] = [:]
    
    public init(
        vapidConfiguration: VAPID.Configuration,
        // TODO: Add networkConfiguration for proxy, number of simultaneous pushes, etc…
        logger: Logger? = nil,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .shared(.singletonMultiThreadedEventLoopGroup)
    ) {
        self.vapidConfiguration = vapidConfiguration
        let allKeys = vapidConfiguration.keys + Array(vapidConfiguration.deprecatedKeys ?? [])
        self.vapidKeyLookup = Dictionary(
            allKeys.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        self.logger = Logger(label: "WebPushManager", factory: { logger?.handler ?? PrintLogHandler(label: $0, metadataProvider: $1) })
        
        var httpClientConfiguration = HTTPClient.Configuration()
        httpClientConfiguration.httpVersion = .automatic
        
        switch eventLoopGroupProvider {
        case .shared(let eventLoopGroup):
            self.httpClient = HTTPClient(
                eventLoopGroupProvider: .shared(eventLoopGroup),
                configuration: httpClientConfiguration,
                backgroundActivityLogger: self.logger
            )
        case .createNew:
            self.httpClient = HTTPClient(
                configuration: httpClientConfiguration,
                backgroundActivityLogger: self.logger
            )
        }
    }
    
    public func run() async throws {
        logger.info("Starting up WebPushManager")
        try await withTaskCancellationOrGracefulShutdownHandler {
            try await gracefulShutdown()
        } onCancelOrGracefulShutdown: { [self] in
            logger.info("Shutting down WebPushManager")
            do {
                try httpClient.syncShutdown()
            } catch {
                logger.error("Graceful Shutdown Failed", metadata: [
                    "error": "\(error)"
                ])
            }
        }
    }
}

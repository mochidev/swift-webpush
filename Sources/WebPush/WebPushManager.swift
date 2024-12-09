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

actor WebPushManager: Sendable {
    public let vapidConfiguration: VAPID.Configuration
    
    nonisolated let logger: Logger
    let httpClient: HTTPClient
    
    let vapidKeyLookup: [VAPID.Key.ID : VAPID.Key]
    var vapidAuthorizationCache: [String : (authorization: String, validUntil: Date)] = [:]
    
    public init(
        vapidConfiguration: VAPID.Configuration,
        // TODO: Add networkConfiguration for proxy, number of simultaneous pushes, etc…
        logger: Logger? = nil,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .shared(.singletonMultiThreadedEventLoopGroup)
    ) {
        assert(vapidConfiguration.validityDuration <= vapidConfiguration.expirationDuration, "The validity duration must be earlier than the expiration duration since it represents when the VAPID Authorization token will be refreshed ahead of it expiring.");
        assert(vapidConfiguration.expirationDuration <= .hours(24), "The expiration duration must be less than 24 hours or else push endpoints will reject messages sent to them.");
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
    
    func loadCurrentVAPIDAuthorizationHeader(
        endpoint: URL,
        signingKey: VAPID.Key
    ) throws -> String {
        let origin = endpoint.origin
        let cacheKey = "\(signingKey.id)|\(origin)"
        
        let now = Date()
        let expirationDate = min(now.adding(vapidConfiguration.expirationDuration), now.adding(.hours(24)))
        let renewalDate = min(now.adding(vapidConfiguration.validityDuration), expirationDate)
        
        if let cachedHeader = vapidAuthorizationCache[cacheKey],
           now < cachedHeader.validUntil
        { return cachedHeader.authorization }
        
        let token = VAPID.Token(
            origin: origin,
            contactInformation: vapidConfiguration.contactInformation,
            expiration: expirationDate
        )
        
        let authorization = try token.generateAuthorization(signedBy: signingKey)
        vapidAuthorizationCache[cacheKey] = (authorization, validUntil: renewalDate)
        
        return authorization
    }
    
    /// Request a VAPID key to supply to the client when requesting a new subscription.
    ///
    /// The ID returned is already in a format that browsers expect `applicationServerKey` to be:
    /// ```js
    /// const serviceRegistration = await navigator.serviceWorker?.register("/serviceWorker.mjs", { type: "module" });
    /// const applicationServerKey = await loadVAPIDKey();
    /// const subscription = await serviceRegistration.pushManager.subscribe({
    ///     userVisibleOnly: true,
    ///     applicationServerKey,
    /// });
    ///
    /// ...
    ///
    /// async function loadVAPIDKey() {
    ///     const httpResponse = await fetch(`/vapidKey`);
    ///
    ///     const webPushOptions = await httpResponse.json();
    ///     if (httpResponse.status != 200) throw new Error(webPushOptions.reason);
    ///
    ///     return webPushOptions.vapid;
    /// }
    /// ```
    ///
    /// Simply provide a route to supply the key, as shown for Vapor below:
    /// ```swift
    /// app.get("vapidKey", use: loadVapidKey)
    ///
    /// ...
    ///
    /// struct WebPushOptions: Codable, Content, Hashable, Sendable {
    ///     static let defaultContentType = HTTPMediaType(type: "application", subType: "webpush-options+json")
    ///
    ///     var vapid: VAPID.Key.ID
    /// }
    ///
    /// @Sendable func loadVapidKey(request: Request) async throws -> WebPushOptions {
    ///     WebPushOptions(vapid: manager.nextVAPIDKeyID)
    /// }
    /// ```
    ///
    /// - Note: If you supplied multiple keys in your VAPID configuration, you must specify the key ID along with the subscription you received from the browser. This can be easily done client side:
    /// ```js
    /// export async function registerSubscription(subscription, applicationServerKey) {
    ///     const subscriptionStatusResponse = await fetch(`/registerSubscription`, {
    ///         method: "POST",
    ///         body: {
    ///             ...subscription.toJSON(),
    ///             applicationServerKey
    ///         }
    ///     });
    ///
    ///     ...
    /// }
    /// ```
    public nonisolated var nextVAPIDKeyID: VAPID.Key.ID {
        vapidConfiguration.primaryKey?.id ?? vapidConfiguration.keys.randomElement()!.id
    }
}

extension WebPushManager: Service {
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

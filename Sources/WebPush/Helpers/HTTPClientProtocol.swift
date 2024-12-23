//
//  HTTPClientProtocol.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-11.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
import Logging
import NIOCore

/// A protocol abstracting HTTP request execution.
package protocol HTTPClientProtocol: Sendable {
    /// Execute the request.
    func execute(
        _ request: HTTPClientRequest,
        deadline: NIODeadline,
        logger: Logger?
    ) async throws -> HTTPClientResponse
    
    /// Shuts down the client.
    func syncShutdown() throws
}

extension HTTPClient: HTTPClientProtocol {}

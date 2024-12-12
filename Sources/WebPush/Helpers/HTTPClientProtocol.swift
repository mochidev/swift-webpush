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

package protocol HTTPClientProtocol: Sendable {
    func execute(
        _ request: HTTPClientRequest,
        deadline: NIODeadline,
        logger: Logger?
    ) async throws -> HTTPClientResponse
    
    func syncShutdown() throws
}

extension HTTPClient: HTTPClientProtocol {}

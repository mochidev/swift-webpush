//
//  MockHTTPClient.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-11.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
import Logging
import NIOCore
@testable import WebPush

actor MockHTTPClient: HTTPClientProtocol {
    var processRequest: (HTTPClientRequest) async throws -> HTTPClientResponse
    
    init(_ processRequest: @escaping (HTTPClientRequest) async throws -> HTTPClientResponse) {
        self.processRequest = processRequest
    }
    
    func execute(
        _ request: HTTPClientRequest,
        deadline: NIODeadline,
        logger: Logger?
    ) async throws -> HTTPClientResponse {
        try await processRequest(request)
    }
    
    nonisolated func syncShutdown() throws {}
}

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
    typealias Handler = (HTTPClientRequest) async throws -> HTTPClientResponse
    var handlers: [Handler]
    var index = 0
    
    init(_ requestHandler: Handler...) {
        self.handlers = requestHandler
    }
    
    func execute(
        _ request: HTTPClientRequest,
        deadline: NIODeadline,
        logger: Logger?
    ) async throws -> HTTPClientResponse {
        let currentHandler = handlers[index]
        index = (index + 1) % handlers.count
        guard deadline >= .now() else { throw HTTPClientError.deadlineExceeded }
        return try await currentHandler(request)
    }
    
    nonisolated func syncShutdown() throws {}
}

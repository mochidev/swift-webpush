//
//  WebPushTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Logging
import ServiceLifecycle
import Testing
@testable import WebPush

@Test func webPushManagerInitializesOnItsOwn() async throws {
    let manager = WebPushManager(vapidConfiguration: .makeTesting())
    await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await manager.run()
        }
        group.cancelAll()
    }
}

@Test func webPushManagerInitializesAsService() async throws {
    let logger = Logger(label: "ServiceLogger", factory: { PrintLogHandler(label: $0, metadataProvider: $1) })
    let manager = WebPushManager(
        vapidConfiguration: .makeTesting(),
        logger: logger
    )
    await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await ServiceGroup(services: [manager], logger: logger).run()
        }
        group.cancelAll()
    }
}

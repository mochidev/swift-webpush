//
//  WebPushTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation
import Logging
import ServiceLifecycle
import Testing
@testable import WebPush

@Suite("WebPush Manager")
struct WebPushManagerTests {
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
    
    @Suite
    struct Expiration {
        @Test func stableConstants() {
            #expect(WebPushManager.Expiration.dropIfUndeliverable == 0)
            #expect(WebPushManager.Expiration.recommendedMaximum == 2_592_000)
        }
        
        @Test func makingExpirations() {
            #expect(WebPushManager.Expiration.zero.seconds == 0)
            
            #expect(WebPushManager.Expiration(seconds: 15).seconds == 15)
            #expect(WebPushManager.Expiration(seconds: -15).seconds == -15)
            
            #expect((15 as WebPushManager.Expiration).seconds == 15)
            #expect((-15 as WebPushManager.Expiration).seconds == -15)
            
            #expect(WebPushManager.Expiration.seconds(15).seconds == 15)
            #expect(WebPushManager.Expiration.seconds(-15).seconds == -15)
            
            #expect(WebPushManager.Expiration.minutes(15).seconds == 900)
            #expect(WebPushManager.Expiration.minutes(-15).seconds == -900)
            
            #expect(WebPushManager.Expiration.hours(15).seconds == 54_000)
            #expect(WebPushManager.Expiration.hours(-15).seconds == -54_000)
            
            #expect(WebPushManager.Expiration.days(15).seconds == 1_296_000)
            #expect(WebPushManager.Expiration.days(-15).seconds == -1_296_000)
        }
        
        @Test func arithmatic() {
            let base: WebPushManager.Expiration = 15
            #expect((base + 15).seconds == 30)
            #expect((base - 15).seconds == 0)
            
            #expect((base - .seconds(30)) == -15)
            #expect((base + .minutes(2)) == 135)
            #expect((base + .minutes(2) + .hours(1)) == 3_735)
            #expect((base + .minutes(2) + .hours(1) + .days(2)) == 176_535)
            #expect((base + .seconds(45) + .minutes(59)) == .hours(1))
        }
        
        @Test func comparison() {
            #expect(WebPushManager.Expiration.seconds(75) < WebPushManager.Expiration.minutes(2))
            #expect(WebPushManager.Expiration.seconds(175) > WebPushManager.Expiration.minutes(2))
        }
        
        @Test func coding() throws {
            #expect(String(decoding: try JSONEncoder().encode(WebPushManager.Expiration(60)), as: UTF8.self) == "60")
            
            #expect(try JSONDecoder().decode(WebPushManager.Expiration.self, from: Data("60".utf8)) == .minutes(1))
        }
    }
}

//
//  MessageSizeTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2025-03-02.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable import WebPush
@testable import WebPushTesting

@Suite("Message Size Tetss")
struct MessageSizeTests {
    @Test func dataMessages() async throws {
        let webPushManager = WebPushManager.makeMockedManager()
        try webPushManager.checkMessageSize(data: Data(repeating: 0, count: 42))
        try webPushManager.checkMessageSize(data: Data(repeating: 0, count: 3993))
        #expect(throws: MessageTooLargeError()) {
            try webPushManager.checkMessageSize(data: Data(repeating: 0, count: 3994))
        }
        
        try WebPushManager._Message.data(Data(repeating: 0, count: 42)).checkMessageSize()
        try WebPushManager._Message.data(Data(repeating: 0, count: 3993)).checkMessageSize()
        #expect(throws: MessageTooLargeError()) {
            try WebPushManager._Message.data(Data(repeating: 0, count: 3994)).checkMessageSize()
        }
    }
    
    @Test func stringMessages() async throws {
        let webPushManager = WebPushManager.makeMockedManager()
        try webPushManager.checkMessageSize(string: String(repeating: "A", count: 42))
        try webPushManager.checkMessageSize(string: String(repeating: "A", count: 3993))
        #expect(throws: MessageTooLargeError()) {
            try webPushManager.checkMessageSize(string: String(repeating: "A", count: 3994))
        }
        
        try WebPushManager._Message.string(String(repeating: "A", count: 42)).checkMessageSize()
        try WebPushManager._Message.string(String(repeating: "A", count: 3993)).checkMessageSize()
        #expect(throws: MessageTooLargeError()) {
            try WebPushManager._Message.string(String(repeating: "A", count: 3994)).checkMessageSize()
        }
    }
    
    @Test func jsonMessages() async throws {
        let webPushManager = WebPushManager.makeMockedManager()
        try webPushManager.checkMessageSize(json: ["key" : String(repeating: "A", count: 42)])
        try webPushManager.checkMessageSize(json: ["key" : String(repeating: "A", count: 3983)])
        #expect(throws: MessageTooLargeError()) {
            try webPushManager.checkMessageSize(json: ["key" : String(repeating: "A", count: 3984)])
        }
        
        try WebPushManager._Message.json(["key" : String(repeating: "A", count: 42)]).checkMessageSize()
        try WebPushManager._Message.json(["key" : String(repeating: "A", count: 3983)]).checkMessageSize()
        #expect(throws: MessageTooLargeError()) {
            try WebPushManager._Message.json(["key" : String(repeating: "A", count: 3984)]).checkMessageSize()
        }
    }
    
    @Test func notificationMessages() async throws {
        let webPushManager = WebPushManager.makeMockedManager()
        try webPushManager.checkMessageSize(notification: PushMessage.Notification(
            destination: URL(string: "https://example.com")!,
            title: String(repeating: "A", count: 42),
            timestamp: Date(timeIntervalSince1970: 1_000_000_000)
        ))
        try webPushManager.checkMessageSize(notification: PushMessage.Notification(
            destination: URL(string: "https://example.com")!,
            title: String(repeating: "A", count: 3889),
            timestamp: Date(timeIntervalSince1970: 1_000_000_000)
        ))
        #expect(throws: MessageTooLargeError()) {
            try webPushManager.checkMessageSize(notification: PushMessage.Notification(
                destination: URL(string: "https://example.com")!,
                title: String(repeating: "A", count: 3890),
                timestamp: Date(timeIntervalSince1970: 1_000_000_000)
            ))
        }
        
        try PushMessage.Notification(
            destination: URL(string: "https://example.com")!,
            title: String(repeating: "A", count: 42),
            timestamp: Date(timeIntervalSince1970: 1_000_000_000)
        ).checkMessageSize()
        try PushMessage.Notification(
            destination: URL(string: "https://example.com")!,
            title: String(repeating: "A", count: 3889),
            timestamp: Date(timeIntervalSince1970: 1_000_000_000)
        ).checkMessageSize()
        #expect(throws: MessageTooLargeError()) {
            try PushMessage.Notification(
                destination: URL(string: "https://example.com")!,
                title: String(repeating: "A", count: 3890),
                timestamp: Date(timeIntervalSince1970: 1_000_000_000)
            ).checkMessageSize()
        }
    }
}

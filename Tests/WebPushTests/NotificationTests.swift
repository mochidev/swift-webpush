//
//  NotificationTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2025-03-01.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable import WebPush

@Suite("Push Message Notification")
struct NotificationTests {
    @Test func simpleNotificationEncodesProperly() async throws {
        let notification = PushMessage.Notification(
            destination: URL(string: "https://jiiiii.moe")!,
            title: "New Anime",
            timestamp: Date(timeIntervalSince1970: 1_000_000_000)
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let encodedString = String(decoding: try encoder.encode(notification), as: UTF8.self)
        #expect(encodedString == """
        {
          "notification" : {
            "navigate" : "https://jiiiii.moe",
            "timestamp" : 1000000000000,
            "title" : "New Anime"
          },
          "web_push" : 8030
        }
        """)
        
        let decodedNotification = try JSONDecoder().decode(PushMessage.SimpleNotification.self, from: Data(encodedString.utf8))
        #expect(decodedNotification == notification)
    }
    
    @Test func legacyNotificationEncodesProperly() async throws {
        let notification = PushMessage.Notification(
            kind: .legacy,
            destination: URL(string: "https://jiiiii.moe")!,
            title: "New Anime",
            timestamp: Date(timeIntervalSince1970: 1_000_000_000)
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let encodedString = String(decoding: try encoder.encode(notification), as: UTF8.self)
        #expect(encodedString == """
        {
          "notification" : {
            "navigate" : "https://jiiiii.moe",
            "timestamp" : 1000000000000,
            "title" : "New Anime"
          }
        }
        """)
        
        let decodedNotification = try JSONDecoder().decode(PushMessage.SimpleNotification.self, from: Data(encodedString.utf8))
        #expect(decodedNotification == notification)
    }
    
    @Test func completeNotificationEncodesProperly() async throws {
        let notification = PushMessage.Notification(
            kind: .declarative,
            destination: URL(string: "https://jiiiii.moe")!,
            title: "New Anime",
            body: "New anime is available!",
            image: URL(string: "https://jiiiii.moe/animeImage")!,
            actions: [
                PushMessage.NotificationAction(
                    id: "ok",
                    label: "OK",
                    destination: URL(string: "https://jiiiii.moe/ok")!,
                    icon: URL(string: "https://jiiiii.moe/okIcon")
                ),
                PushMessage.NotificationAction(
                    id: "cancel",
                    label: "Cancel",
                    destination: URL(string: "https://jiiiii.moe/cancel")!,
                    icon: URL(string: "https://jiiiii.moe/cancelIcon")
                ),
            ],
            timestamp: Date(timeIntervalSince1970: 1_000_000_000),
            appBadgeCount: 0,
            isMutable: true,
            options: PushMessage.NotificationOptions(
                direction: .rightToLeft,
                language: "jp",
                tag: "new-anime",
                icon: URL(string: "https://jiiiii.moe/icon")!,
                badgeIcon: URL(string: "https://jiiiii.moe/badgeIcon")!,
                vibrate: [200, 100, 200],
                shouldRenotify: true,
                isSilent: true,
                requiresInteraction: true
            )
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let encodedString = String(decoding: try encoder.encode(notification), as: UTF8.self)
        #expect(encodedString == """
        {
          "app_badge" : 0,
          "mutable" : true,
          "notification" : {
            "actions" : [
              {
                "action" : "ok",
                "icon" : "https://jiiiii.moe/okIcon",
                "navigate" : "https://jiiiii.moe/ok",
                "title" : "OK"
              },
              {
                "action" : "cancel",
                "icon" : "https://jiiiii.moe/cancelIcon",
                "navigate" : "https://jiiiii.moe/cancel",
                "title" : "Cancel"
              }
            ],
            "badge" : "https://jiiiii.moe/badgeIcon",
            "body" : "New anime is available!",
            "dir" : "rtf",
            "icon" : "https://jiiiii.moe/icon",
            "image" : "https://jiiiii.moe/animeImage",
            "lang" : "jp",
            "navigate" : "https://jiiiii.moe",
            "renotify" : true,
            "require_interaction" : true,
            "silent" : true,
            "tag" : "new-anime",
            "timestamp" : 1000000000000,
            "title" : "New Anime",
            "vibrate" : [
              200,
              100,
              200
            ]
          },
          "web_push" : 8030
        }
        """)
        
        let decodedNotification = try JSONDecoder().decode(PushMessage.SimpleNotification.self, from: Data(encodedString.utf8))
        #expect(decodedNotification == notification)
    }
    
    @Test func customNotificationEncodesProperly() async throws {
        let notification = PushMessage.Notification(
            destination: URL(string: "https://jiiiii.moe")!,
            title: "New Anime",
            timestamp: Date(timeIntervalSince1970: 1_000_000_000),
            data: ["episodeID": "123"]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let encodedString = String(decoding: try encoder.encode(notification), as: UTF8.self)
        #expect(encodedString == """
        {
          "notification" : {
            "data" : {
              "episodeID" : "123"
            },
            "navigate" : "https://jiiiii.moe",
            "timestamp" : 1000000000000,
            "title" : "New Anime"
          },
          "web_push" : 8030
        }
        """)
        
        let decodedNotification = try JSONDecoder().decode(type(of: notification), from: Data(encodedString.utf8))
        #expect(decodedNotification == notification)
    }
}

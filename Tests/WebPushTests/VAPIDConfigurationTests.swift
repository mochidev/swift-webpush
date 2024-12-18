//
//  VAPIDConfigurationTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-15.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Crypto
import Foundation
import Testing
@testable import WebPush
import WebPushTesting

@Suite("VAPID Configuration Tests")
struct VAPIDConfigurationTests {
    @Suite
    struct Initialization {
        @Test func primaryKeyOnly() {
            let config = VAPID.Configuration(
                key: .mockedKey1,
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == .mockedKey1)
            #expect(config.keys == [.mockedKey1])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func emptyDeprecatedKeys() {
            let config = VAPID.Configuration(
                key: .mockedKey1,
                deprecatedKeys: [],
                contactInformation: .url(URL(string: "https://example.com")!),
                expirationDuration: .hours(24),
                validityDuration: .hours(12)
            )
            #expect(config.primaryKey == .mockedKey1)
            #expect(config.keys == [.mockedKey1])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .url(URL(string: "https://example.com")!))
            #expect(config.expirationDuration == .hours(24))
            #expect(config.validityDuration == .hours(12))
        }
        
        @Test func deprecatedKeys() {
            let config = VAPID.Configuration(
                key: .mockedKey1,
                deprecatedKeys: [.mockedKey2, .mockedKey3],
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == .mockedKey1)
            #expect(config.keys == [.mockedKey1])
            #expect(config.deprecatedKeys == [.mockedKey2, .mockedKey3])
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func deprecatedAndPrimaryKeys() {
            let config = VAPID.Configuration(
                key: .mockedKey1,
                deprecatedKeys: [.mockedKey2, .mockedKey3, .mockedKey1],
                contactInformation: .url(URL(string: "https://example.com")!),
                expirationDuration: .hours(24),
                validityDuration: .hours(12)
            )
            #expect(config.primaryKey == .mockedKey1)
            #expect(config.keys == [.mockedKey1])
            #expect(config.deprecatedKeys == [.mockedKey2, .mockedKey3])
            #expect(config.contactInformation == .url(URL(string: "https://example.com")!))
            #expect(config.expirationDuration == .hours(24))
            #expect(config.validityDuration == .hours(12))
        }
        
        @Test func multipleKeys() throws {
            let config = try VAPID.Configuration(
                primaryKey: nil,
                keys: [.mockedKey1, .mockedKey2],
                deprecatedKeys: nil,
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == nil)
            #expect(config.keys == [.mockedKey1, .mockedKey2])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func noKeys() throws {
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try VAPID.Configuration(
                    primaryKey: nil,
                    keys: [],
                    deprecatedKeys: [.mockedKey2, .mockedKey3],
                    contactInformation: .email("test@email.com")
                )
            }
        }
        
        @Test func multipleAndDeprecatedKeys() throws {
            let config = try VAPID.Configuration(
                primaryKey: nil,
                keys: [.mockedKey1, .mockedKey2],
                deprecatedKeys: [.mockedKey2],
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == nil)
            #expect(config.keys == [.mockedKey1, .mockedKey2])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func multipleAndPrimaryKeys() throws {
            let config = try VAPID.Configuration(
                primaryKey: .mockedKey1,
                keys: [.mockedKey2],
                deprecatedKeys: [.mockedKey2, .mockedKey3, .mockedKey1],
                contactInformation: .url(URL(string: "https://example.com")!),
                expirationDuration: .hours(24),
                validityDuration: .hours(12)
            )
            #expect(config.primaryKey == .mockedKey1)
            #expect(config.keys == [.mockedKey1, .mockedKey2])
            #expect(config.deprecatedKeys == [.mockedKey3])
            #expect(config.contactInformation == .url(URL(string: "https://example.com")!))
            #expect(config.expirationDuration == .hours(24))
            #expect(config.validityDuration == .hours(12))
        }
    }
    
    @Suite
    struct Updates {
        @Test func primaryKeyOnly() throws {
            var config = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: .mockedKey2, keys: [], deprecatedKeys: nil)
            #expect(config.primaryKey == .mockedKey2)
            #expect(config.keys == [.mockedKey2])
            #expect(config.deprecatedKeys == nil)
        }
        
        @Test func noKeys() throws {
            var config = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@email.com"))
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try config.updateKeys(primaryKey: nil, keys: [], deprecatedKeys: nil)
            }
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try config.updateKeys(primaryKey: nil, keys: [], deprecatedKeys: [])
            }
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try config.updateKeys(primaryKey: nil, keys: [], deprecatedKeys: [.mockedKey1])
            }
        }
        
        @Test func multipleKeys() throws {
            var config = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: nil, keys: [.mockedKey2], deprecatedKeys: nil)
            #expect(config.primaryKey == nil)
            #expect(config.keys == [.mockedKey2])
            #expect(config.deprecatedKeys == nil)
            
            try config.updateKeys(primaryKey: nil, keys: [.mockedKey2, .mockedKey3], deprecatedKeys: nil)
            #expect(config.primaryKey == nil)
            #expect(config.keys == [.mockedKey2, .mockedKey3])
            #expect(config.deprecatedKeys == nil)
        }
        
        @Test func multipleAndDeprecatedKeys() throws {
            var config = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: nil, keys: [.mockedKey2], deprecatedKeys: [.mockedKey2, .mockedKey3])
            #expect(config.primaryKey == nil)
            #expect(config.keys == [.mockedKey2])
            #expect(config.deprecatedKeys == [.mockedKey3])
            
            try config.updateKeys(primaryKey: nil, keys: [.mockedKey2, .mockedKey3], deprecatedKeys: [.mockedKey2, .mockedKey3])
            #expect(config.primaryKey == nil)
            #expect(config.keys == [.mockedKey2, .mockedKey3])
            #expect(config.deprecatedKeys == nil)
        }
        
        @Test func multipleAndPrimaryKeys() throws {
            var config = VAPID.Configuration(key: .mockedKey1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: .mockedKey2, keys: [.mockedKey3], deprecatedKeys: [.mockedKey1, .mockedKey2, .mockedKey3])
            #expect(config.primaryKey == .mockedKey2)
            #expect(config.keys == [.mockedKey2, .mockedKey3])
            #expect(config.deprecatedKeys == [.mockedKey1])
            
            try config.updateKeys(primaryKey: .mockedKey2, keys: [.mockedKey3], deprecatedKeys: [.mockedKey2, .mockedKey3])
            #expect(config.primaryKey == .mockedKey2)
            #expect(config.keys == [.mockedKey2, .mockedKey3])
            #expect(config.deprecatedKeys == nil)
        }
    }
    
    @Suite
    struct Coding {
        func encode(_ configuration: VAPID.Configuration) throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(configuration), as: UTF8.self)
        }
        
        @Test func encodesPrimaryKeyOnly() async throws {
            #expect(
                try encode(.init(key: .mockedKey1, contactInformation: .email("test@example.com"))) ==
                """
                {
                  "contactInformation" : "mailto:test@example.com",
                  "expirationDuration" : 79200,
                  "primaryKey" : "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=",
                  "validityDuration" : 72000
                }
                """
            )
        }
        
        @Test func encodesMultipleKeysWithoutDuplicates() async throws {
            #expect(
                try encode(.init(
                    primaryKey: .mockedKey1,
                    keys: [.mockedKey2],
                    deprecatedKeys: [.mockedKey1, .mockedKey2, .mockedKey3],
                    contactInformation: .email("test@example.com"),
                    expirationDuration: .hours(1),
                    validityDuration: .hours(10)
                )) ==
                """
                {
                  "contactInformation" : "mailto:test@example.com",
                  "deprecatedKeys" : [
                    "bcZgo/p2WFqXaKFzmYaDKO/gARjWvGi3oXyHM2QNlfE="
                  ],
                  "expirationDuration" : 3600,
                  "keys" : [
                    "wyQaGWNwvXKzVmPIhkqVQvQ+FKx1SNqHJ+re8n2ORrk="
                  ],
                  "primaryKey" : "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=",
                  "validityDuration" : 36000
                }
                """
            )
        }
        
        @Test func decodesIncompleteConfiguration() throws {
            #expect(
                try JSONDecoder().decode(VAPID.Configuration.self, from: Data(
                    """
                    {
                      "contactInformation" : "mailto:test@example.com",
                      "expirationDuration" : 79200,
                      "primaryKey" : "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=",
                      "validityDuration" : 72000
                    }
                    """.utf8
                )) ==
                VAPID.Configuration(
                    key: .mockedKey1,
                    contactInformation: .email("test@example.com")
                )
            )
        }
        
        @Test func decodesWholeConfiguration() throws {
            #expect(
                try JSONDecoder().decode(VAPID.Configuration.self, from: Data(
                    """
                    {
                      "contactInformation" : "mailto:test@example.com",
                      "deprecatedKeys" : [
                        "bcZgo/p2WFqXaKFzmYaDKO/gARjWvGi3oXyHM2QNlfE="
                      ],
                      "expirationDuration" : 3600,
                      "keys" : [
                        "wyQaGWNwvXKzVmPIhkqVQvQ+FKx1SNqHJ+re8n2ORrk="
                      ],
                      "primaryKey" : "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=",
                      "validityDuration" : 36000
                    }
                    """.utf8
                )) ==
                VAPID.Configuration(
                    primaryKey: .mockedKey1,
                    keys: [.mockedKey2],
                    deprecatedKeys: [.mockedKey1, .mockedKey2, .mockedKey3],
                    contactInformation: .email("test@example.com"),
                    expirationDuration: .hours(1),
                    validityDuration: .hours(10)
                )
            )
        }
    }
    
    @Suite
    struct Duration {
        @Test func makingDurations() {
            #expect(VAPID.Configuration.Duration.zero.seconds == 0)
            
            #expect(VAPID.Configuration.Duration(seconds: 15).seconds == 15)
            #expect(VAPID.Configuration.Duration(seconds: -15).seconds == -15)
            
            #expect((15 as VAPID.Configuration.Duration).seconds == 15)
            #expect((-15 as VAPID.Configuration.Duration).seconds == -15)
            
            #expect(VAPID.Configuration.Duration.seconds(15).seconds == 15)
            #expect(VAPID.Configuration.Duration.seconds(-15).seconds == -15)
            
            #expect(VAPID.Configuration.Duration.minutes(15).seconds == 900)
            #expect(VAPID.Configuration.Duration.minutes(-15).seconds == -900)
            
            #expect(VAPID.Configuration.Duration.hours(15).seconds == 54_000)
            #expect(VAPID.Configuration.Duration.hours(-15).seconds == -54_000)
            
            #expect(VAPID.Configuration.Duration.days(15).seconds == 1_296_000)
            #expect(VAPID.Configuration.Duration.days(-15).seconds == -1_296_000)
        }
        
        @Test func arithmatic() {
            let base: VAPID.Configuration.Duration = 15
            #expect((base + 15).seconds == 30)
            #expect((base - 15).seconds == 0)
            
            #expect((base - .seconds(30)) == -15)
            #expect((base + .minutes(2)) == 135)
            #expect((base + .minutes(2) + .hours(1)) == 3_735)
            #expect((base + .minutes(2) + .hours(1) + .days(2)) == 176_535)
            #expect((base + .seconds(45) + .minutes(59)) == .hours(1))
        }
        
        @Test func comparison() {
            #expect(VAPID.Configuration.Duration.seconds(75) < VAPID.Configuration.Duration.minutes(2))
            #expect(VAPID.Configuration.Duration.seconds(175) > VAPID.Configuration.Duration.minutes(2))
        }
        
        @Test func addingToDates() {
            let now = Date()
            #expect(now.adding(.seconds(5)) == now.addingTimeInterval(5))
        }
        
        @Test func coding() throws {
            #expect(String(decoding: try JSONEncoder().encode(VAPID.Configuration.Duration(60)), as: UTF8.self) == "60")
            
            #expect(try JSONDecoder().decode(VAPID.Configuration.Duration.self, from: Data("60".utf8)) == .minutes(1))
        }
    }
}

@Suite("Contact Information Coding")
struct ContactInformationCoding {
    @Test func encodesToString() async throws {
        func encode(_ contactInformation: VAPID.Configuration.ContactInformation) throws -> String {
            String(decoding: try JSONEncoder().encode(contactInformation), as: UTF8.self)
        }
        #expect(try encode(.email("test@example.com")) == "\"mailto:test@example.com\"")
        #expect(try encode(.email("junk")) == "\"mailto:junk\"")
        #expect(try encode(.email("")) == "\"mailto:\"")
        #expect(try encode(.url(URL(string: "https://example.com")!)) == "\"https:\\/\\/example.com\"")
        #expect(try encode(.url(URL(string: "junk")!)) == "\"junk\"")
    }
    
    @Test func decodesFromString() async throws {
        func decode(_ string: String) throws -> VAPID.Configuration.ContactInformation {
            try JSONDecoder().decode(VAPID.Configuration.ContactInformation.self, from: Data(string.utf8))
        }
        #expect(try decode("\"mailto:test@example.com\"") == .email("test@example.com"))
        #expect(try decode("\"mailto:junk\"") == .email("junk"))
        #expect(try decode("\"https://example.com\"") == .url(URL(string: "https://example.com")!))
        #expect(try decode("\"HTTP://example.com\"") == .url(URL(string: "HTTP://example.com")!))
        
        #expect(throws: DecodingError.self) {
            try decode("\"\"")
        }
        
        #expect(throws: DecodingError.self) {
            try decode("\"junk\"")
        }
        
        #expect(throws: DecodingError.self) {
            try decode("\"file:///Users/you/Library\"")
        }
        
        #expect(throws: DecodingError.self) {
            try decode("\"mailto:\"")
        }
    }
}

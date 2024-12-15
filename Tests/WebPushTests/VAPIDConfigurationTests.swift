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

@Suite("VAPID Configuration Tests")
struct VAPIDConfigurationTests {
    @Suite
    struct Initialization {
        let key1 = try! VAPID.Key(base64URLEncoded: "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=")
        let key2 = try! VAPID.Key(base64URLEncoded: "wyQaGWNwvXKzVmPIhkqVQvQ+FKx1SNqHJ+re8n2ORrk=")
        let key3 = try! VAPID.Key(base64URLEncoded: "bcZgo/p2WFqXaKFzmYaDKO/gARjWvGi3oXyHM2QNlfE=")
        
        @Test func primaryKeyOnly() {
            let config = VAPID.Configuration(
                key: key1,
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == key1)
            #expect(config.keys == [key1])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func emptyDeprecatedKeys() {
            let config = VAPID.Configuration(
                key: key1,
                deprecatedKeys: [],
                contactInformation: .url(URL(string: "https://example.com")!),
                expirationDuration: .hours(24),
                validityDuration: .hours(12)
            )
            #expect(config.primaryKey == key1)
            #expect(config.keys == [key1])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .url(URL(string: "https://example.com")!))
            #expect(config.expirationDuration == .hours(24))
            #expect(config.validityDuration == .hours(12))
        }
        
        @Test func deprecatedKeys() {
            let config = VAPID.Configuration(
                key: key1,
                deprecatedKeys: [key2, key3],
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == key1)
            #expect(config.keys == [key1])
            #expect(config.deprecatedKeys == [key2, key3])
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func deprecatedAndPrimaryKeys() {
            let config = VAPID.Configuration(
                key: key1,
                deprecatedKeys: [key2, key3, key1],
                contactInformation: .url(URL(string: "https://example.com")!),
                expirationDuration: .hours(24),
                validityDuration: .hours(12)
            )
            #expect(config.primaryKey == key1)
            #expect(config.keys == [key1])
            #expect(config.deprecatedKeys == [key2, key3])
            #expect(config.contactInformation == .url(URL(string: "https://example.com")!))
            #expect(config.expirationDuration == .hours(24))
            #expect(config.validityDuration == .hours(12))
        }
        
        @Test func multipleKeys() throws {
            let config = try VAPID.Configuration(
                primaryKey: nil,
                keys: [key1, key2],
                deprecatedKeys: nil,
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == nil)
            #expect(config.keys == [key1, key2])
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
                    deprecatedKeys: [key2, key3],
                    contactInformation: .email("test@email.com")
                )
            }
        }
        
        @Test func multipleAndDeprecatedKeys() throws {
            let config = try VAPID.Configuration(
                primaryKey: nil,
                keys: [key1, key2],
                deprecatedKeys: [key2],
                contactInformation: .email("test@email.com")
            )
            #expect(config.primaryKey == nil)
            #expect(config.keys == [key1, key2])
            #expect(config.deprecatedKeys == nil)
            #expect(config.contactInformation == .email("test@email.com"))
            #expect(config.expirationDuration == .hours(22))
            #expect(config.validityDuration == .hours(20))
        }
        
        @Test func multipleAndPrimaryKeys() throws {
            let config = try VAPID.Configuration(
                primaryKey: key1,
                keys: [key2],
                deprecatedKeys: [key2, key3, key1],
                contactInformation: .url(URL(string: "https://example.com")!),
                expirationDuration: .hours(24),
                validityDuration: .hours(12)
            )
            #expect(config.primaryKey == key1)
            #expect(config.keys == [key1, key2])
            #expect(config.deprecatedKeys == [key3])
            #expect(config.contactInformation == .url(URL(string: "https://example.com")!))
            #expect(config.expirationDuration == .hours(24))
            #expect(config.validityDuration == .hours(12))
        }
    }
    
    @Suite
    struct Updates {
        let key1 = try! VAPID.Key(base64URLEncoded: "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=")
        let key2 = try! VAPID.Key(base64URLEncoded: "wyQaGWNwvXKzVmPIhkqVQvQ+FKx1SNqHJ+re8n2ORrk=")
        let key3 = try! VAPID.Key(base64URLEncoded: "bcZgo/p2WFqXaKFzmYaDKO/gARjWvGi3oXyHM2QNlfE=")
        
        @Test func primaryKeyOnly() throws {
            var config = VAPID.Configuration(key: key1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: key2, keys: [], deprecatedKeys: nil)
            #expect(config.primaryKey == key2)
            #expect(config.keys == [key2])
            #expect(config.deprecatedKeys == nil)
        }
        
        @Test func noKeys() throws {
            var config = VAPID.Configuration(key: key1, contactInformation: .email("test@email.com"))
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try config.updateKeys(primaryKey: nil, keys: [], deprecatedKeys: nil)
            }
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try config.updateKeys(primaryKey: nil, keys: [], deprecatedKeys: [])
            }
            #expect(throws: VAPID.ConfigurationError.keysNotProvided) {
                try config.updateKeys(primaryKey: nil, keys: [], deprecatedKeys: [key1])
            }
        }
        
        @Test func multipleKeys() throws {
            var config = VAPID.Configuration(key: key1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: nil, keys: [key2], deprecatedKeys: nil)
            #expect(config.primaryKey == nil)
            #expect(config.keys == [key2])
            #expect(config.deprecatedKeys == nil)
            
            try config.updateKeys(primaryKey: nil, keys: [key2, key3], deprecatedKeys: nil)
            #expect(config.primaryKey == nil)
            #expect(config.keys == [key2, key3])
            #expect(config.deprecatedKeys == nil)
        }
        
        @Test func multipleAndDeprecatedKeys() throws {
            var config = VAPID.Configuration(key: key1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: nil, keys: [key2], deprecatedKeys: [key2, key3])
            #expect(config.primaryKey == nil)
            #expect(config.keys == [key2])
            #expect(config.deprecatedKeys == [key3])
            
            try config.updateKeys(primaryKey: nil, keys: [key2, key3], deprecatedKeys: [key2, key3])
            #expect(config.primaryKey == nil)
            #expect(config.keys == [key2, key3])
            #expect(config.deprecatedKeys == nil)
        }
        
        @Test func multipleAndPrimaryKeys() throws {
            var config = VAPID.Configuration(key: key1, contactInformation: .email("test@email.com"))
            
            try config.updateKeys(primaryKey: key2, keys: [key3], deprecatedKeys: [key1, key2, key3])
            #expect(config.primaryKey == key2)
            #expect(config.keys == [key2, key3])
            #expect(config.deprecatedKeys == [key1])
            
            try config.updateKeys(primaryKey: key2, keys: [key3], deprecatedKeys: [key2, key3])
            #expect(config.primaryKey == key2)
            #expect(config.keys == [key2, key3])
            #expect(config.deprecatedKeys == nil)
        }
    }
    
    @Suite
    struct Coding {
        let key1 = try! VAPID.Key(base64URLEncoded: "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=")
        let key2 = try! VAPID.Key(base64URLEncoded: "wyQaGWNwvXKzVmPIhkqVQvQ+FKx1SNqHJ+re8n2ORrk=")
        let key3 = try! VAPID.Key(base64URLEncoded: "bcZgo/p2WFqXaKFzmYaDKO/gARjWvGi3oXyHM2QNlfE=")
        
        func encode(_ configuration: VAPID.Configuration) throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(configuration), as: UTF8.self)
        }
        
        @Test func encodesPrimaryKeyOnly() async throws {
            #expect(
                try encode(.init(key: key1, contactInformation: .email("test@example.com"))) ==
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
                    primaryKey: key1,
                    keys: [key2],
                    deprecatedKeys: [key1, key2, key3],
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

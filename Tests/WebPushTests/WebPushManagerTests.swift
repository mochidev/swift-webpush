//
//  WebPushManagerTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
@preconcurrency import Crypto
import Foundation
import Logging
import ServiceLifecycle
import Testing
@testable import WebPush
import WebPushTesting

@Suite("WebPush Manager")
struct WebPushManagerTests {
    @Suite
    struct Initialization {
        @Test func managerInitializesOnItsOwn() async throws {
            let manager = WebPushManager(vapidConfiguration: .makeTesting())
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await manager.run()
                }
                group.cancelAll()
            }
        }
        
        @Test func managerInitializesAsService() async throws {
            let logger = Logger(label: "ServiceLogger", factory: { PrintLogHandler(label: $0, metadataProvider: $1) })
            let manager = WebPushManager(
                vapidConfiguration: .makeTesting(),
                backgroundActivityLogger: logger
            )
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await ServiceGroup(services: [manager], logger: logger).run()
                }
                group.cancelAll()
            }
        }
        
        @Test func managerCanCreateThreadPool() async throws {
            let manager = WebPushManager(vapidConfiguration: .makeTesting(), eventLoopGroupProvider: .createNew)
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await manager.run()
                }
                group.cancelAll()
            }
        }
        
        @Test func managerCanBeMocked() async throws {
            let manager = WebPushManager.makeMockedManager { _, _, _, _ in }
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await manager.run()
                }
                group.cancelAll()
            }
        }
        
        /// Enable when https://github.com/swiftlang/swift-testing/blob/jgrynspan/exit-tests-proposal/Documentation/Proposals/NNNN-exit-tests.md gets accepted.
//        @Test func managerCatchesIncorrectValidity() async throws {
//            await #expect(exitsWith: .failure) {
//                var configuration = VAPID.Configuration(key: .init(), contactInformation: .email("test@example.com"))
//                configuration.validityDuration = .days(2)
//                let _ = WebPushManager(vapidConfiguration: configuration)
//            }
//        }
        
        @Test func managerConstructsAValidKeyLookup() async throws {
            let configuration = try VAPID.Configuration(primaryKey: .mockedKey1, keys: [.mockedKey2], deprecatedKeys: [.mockedKey3], contactInformation: .email("test@example.com"))
            let manager = WebPushManager(vapidConfiguration: configuration)
            #expect(await manager.vapidKeyLookup == [
                .mockedKeyID1 : .mockedKey1,
                .mockedKeyID2 : .mockedKey2,
                .mockedKeyID3 : .mockedKey3,
            ])
        }
        
        /// This is needed to cover the `uniquingKeysWith` safety call completely.
        @Test func managerConstructsAValidKeyLookupFromQuestionableConfiguration() async throws {
            var configuration = VAPID.Configuration.mockedConfiguration
            configuration.unsafeUpdateKeys(primaryKey: .mockedKey1, keys: [.mockedKey1], deprecatedKeys: [.mockedKey1])
            let manager = WebPushManager(vapidConfiguration: configuration)
            #expect(await manager.vapidKeyLookup == [.mockedKeyID1 : .mockedKey1])
        }
    }
    
    @Suite("VAPID Key Retrieval") struct VAPIDKeyRetrieval {
        @Test func retrievesPrimaryKey() async {
            let manager = WebPushManager(vapidConfiguration: .mockedConfiguration)
            #expect(manager.nextVAPIDKeyID == .mockedKeyID1)
        }
        
        @Test func alwaysRetrievesPrimaryKey() async throws {
            var configuration = VAPID.Configuration.mockedConfiguration
            try configuration.updateKeys(primaryKey: .mockedKey1, keys: [.mockedKey2], deprecatedKeys: [.mockedKey3])
            let manager = WebPushManager(vapidConfiguration: configuration)
            for _ in 0..<100_000 {
                #expect(manager.nextVAPIDKeyID == .mockedKeyID1)
            }
        }
        
        @Test func retrievesFallbackKeys() async throws {
            var configuration = VAPID.Configuration.mockedConfiguration
            try configuration.updateKeys(primaryKey: nil, keys: [.mockedKey1, .mockedKey2])
            let manager = WebPushManager(vapidConfiguration: configuration)
            var keyCounts: [VAPID.Key.ID : Int] = [:]
            for _ in 0..<100_000 {
                keyCounts[manager.nextVAPIDKeyID, default: 0] += 1
            }
            #expect(abs(keyCounts[.mockedKeyID1, default: 0] - keyCounts[.mockedKeyID2, default: 0]) < 1_000) /// If this test fails, increase this number accordingly
        }
        
        @Test func neverRetrievesDeprecatedKeys() async throws {
            var configuration = VAPID.Configuration.mockedConfiguration
            try configuration.updateKeys(primaryKey: nil, keys: [.mockedKey1, .mockedKey2], deprecatedKeys: [.mockedKey3])
            let manager = WebPushManager(vapidConfiguration: configuration)
            for _ in 0..<100_000 {
                #expect(manager.nextVAPIDKeyID != .mockedKeyID3)
            }
        }
        
        @Test func keyStatus() async throws {
            var configuration = VAPID.Configuration.mockedConfiguration
            try configuration.updateKeys(primaryKey: .mockedKey1, keys: [.mockedKey2], deprecatedKeys: [.mockedKey3])
            let manager = WebPushManager(vapidConfiguration: configuration)
            #expect(manager.keyStatus(for: .mockedKeyID1) == .valid)
            #expect(manager.keyStatus(for: .mockedKeyID2) == .valid)
            #expect(manager.keyStatus(for: .mockedKeyID3) == .deprecated)
            #expect(manager.keyStatus(for: .mockedKeyID4) == .unknown)
        }
    }
    
    @Suite("Sending Messages")
    struct SendingMessages {
        func validateAuthotizationHeader(
            request: HTTPClientRequest,
            vapidConfiguration: VAPID.Configuration,
            origin: String
        ) throws {
            let auth = try #require(request.headers["Authorization"].first)
            let components = auth.split(separator: ",")
            let tComponents = try #require(components.first).split(separator: "=")
            let kComponents = try #require(components.last).split(separator: "=")
            let t = String(try #require(tComponents.last).trimming(while: \.isWhitespace))
            let k = String(try #require(kComponents.last).trimming(while: \.isWhitespace))
            #expect(k == vapidConfiguration.primaryKey?.id.description)
            
            let decodedToken = try #require(VAPID.Token(token: t, key: k))
            #expect(decodedToken.audience == origin)
            #expect(decodedToken.subject == vapidConfiguration.contactInformation)
            #expect(decodedToken.expiration > Int(Date().timeIntervalSince1970))
        }
        
        func decrypt(
            request: HTTPClientRequest,
            userAgentPrivateKey: P256.KeyAgreement.PrivateKey,
            userAgentKeyMaterial: UserAgentKeyMaterial
        ) async throws -> [UInt8] {
            var body = try #require(try await request.body?.collect(upTo: 16*1024))
            #expect(body.readableBytes == 4096)
            
            let salt = body.readBytes(length: 16)
            let recordSize = body.readInteger(as: UInt32.self)
            #expect(try #require(recordSize) == 4010)
            let keyIDSize = body.readInteger(as: UInt8.self)
            let keyID = body.readBytes(length: Int(keyIDSize ?? 0))
            
            let userAgent = userAgentKeyMaterial
            let applicationServerECDHPublicKey = try P256.KeyAgreement.PublicKey(x963Representation: try #require(keyID))
            
            let sharedSecret = try userAgentPrivateKey.sharedSecretFromKeyAgreement(with: applicationServerECDHPublicKey)
            
            let keyInfo = "WebPush: info".utf8Bytes + [0x00] + userAgent.publicKey.x963Representation + applicationServerECDHPublicKey.x963Representation
            let inputKeyMaterial = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: userAgent.authenticationSecret,
                sharedInfo: keyInfo,
                outputByteCount: 32
            )
            
            let contentEncryptionKeyInfo = "Content-Encoding: aes128gcm".utf8Bytes + [0x00]
            let contentEncryptionKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: try #require(salt), info: contentEncryptionKeyInfo, outputByteCount: 16)
            
            let nonceInfo = "Content-Encoding: nonce".utf8Bytes + [0x00]
            let nonce = try HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: try #require(salt), info: nonceInfo, outputByteCount: 12)
                .withUnsafeBytes(AES.GCM.Nonce.init(data:))
            
            let cypherText = body.readBytes(length: body.readableBytes - 16)
            let tag = body.readBytes(length: 16)
            let encryptedRecord = try AES.GCM.SealedBox(nonce: nonce, ciphertext: #require(cypherText), tag: #require(tag))
            
            let paddedPayload = try AES.GCM.open(encryptedRecord, using: contentEncryptionKey)
            
            return paddedPayload.trimmingSuffix { $0 == 0 }.dropLast()
        }
        
        @Test func sendSuccessfulTextMessage() async throws {
            try await confirmation { requestWasMade in
                let vapidConfiguration = VAPID.Configuration.makeTesting()
                
                let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
                var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
                for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
                
                let subscriber = Subscriber(
                    endpoint: URL(string: "https://example.com/subscriber")!,
                    userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
                    vapidKeyID: vapidConfiguration.primaryKey!.id
                )
                
                let manager = WebPushManager(
                    vapidConfiguration: vapidConfiguration,
                    backgroundActivityLogger: Logger(label: "WebPushManagerTests", factory: { PrintLogHandler(label: $0, metadataProvider: $1) }),
                    executor: .httpClient(MockHTTPClient({ request in
                        try validateAuthotizationHeader(
                            request: request,
                            vapidConfiguration: vapidConfiguration,
                            origin: "https://example.com"
                        )
                        #expect(request.method == .POST)
                        #expect(request.headers["Content-Encoding"] == ["aes128gcm"])
                        #expect(request.headers["Content-Type"] == ["application/octet-stream"])
                        #expect(request.headers["TTL"] == ["2592000"])
                        #expect(request.headers["Urgency"] == ["high"])
                        #expect(request.headers["Topic"] == []) // TODO: Update when topic is added
                        
                        let message = try await decrypt(
                            request: request,
                            userAgentPrivateKey: subscriberPrivateKey,
                            userAgentKeyMaterial: subscriber.userAgentKeyMaterial
                        )
                        
                        #expect(String(decoding: message, as: UTF8.self) == "hello")
                        
                        requestWasMade()
                        return HTTPClientResponse(status: .created)
                    }))
                )
                
                try await manager.send(string: "hello", to: subscriber)
            }
        }
        
        @Test func sendSuccessfulDataMessage() async throws {
            try await confirmation { requestWasMade in
                let vapidConfiguration = VAPID.Configuration.makeTesting()
                
                let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
                var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
                for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
                
                let subscriber = Subscriber(
                    endpoint: URL(string: "https://example.com/subscriber")!,
                    userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
                    vapidKeyID: vapidConfiguration.primaryKey!.id
                )
                
                let manager = WebPushManager(
                    vapidConfiguration: vapidConfiguration,
                    backgroundActivityLogger: Logger(label: "WebPushManagerTests", factory: { PrintLogHandler(label: $0, metadataProvider: $1) }),
                    executor: .httpClient(MockHTTPClient({ request in
                        try validateAuthotizationHeader(
                            request: request,
                            vapidConfiguration: vapidConfiguration,
                            origin: "https://example.com"
                        )
                        #expect(request.method == .POST)
                        #expect(request.headers["Content-Encoding"] == ["aes128gcm"])
                        #expect(request.headers["Content-Type"] == ["application/octet-stream"])
                        #expect(request.headers["TTL"] == ["2592000"])
                        #expect(request.headers["Urgency"] == ["high"])
                        #expect(request.headers["Topic"] == []) // TODO: Update when topic is added
                        
                        let message = try await decrypt(
                            request: request,
                            userAgentPrivateKey: subscriberPrivateKey,
                            userAgentKeyMaterial: subscriber.userAgentKeyMaterial
                        )
                        
                        #expect(String(decoding: message, as: UTF8.self) == "hello")
                        
                        requestWasMade()
                        return HTTPClientResponse(status: .created)
                    }))
                )
                
                try await manager.send(data: "hello".utf8Bytes, to: subscriber)
            }
        }
        
        @Test func sendSuccessfulJSONMessage() async throws {
            try await confirmation { requestWasMade in
                let vapidConfiguration = VAPID.Configuration.makeTesting()
                
                let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
                var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
                for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
                
                let subscriber = Subscriber(
                    endpoint: URL(string: "https://example.com/subscriber")!,
                    userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
                    vapidKeyID: vapidConfiguration.primaryKey!.id
                )
                
                let manager = WebPushManager(
                    vapidConfiguration: vapidConfiguration,
                    backgroundActivityLogger: Logger(label: "WebPushManagerTests", factory: { PrintLogHandler(label: $0, metadataProvider: $1) }),
                    executor: .httpClient(MockHTTPClient({ request in
                        try validateAuthotizationHeader(
                            request: request,
                            vapidConfiguration: vapidConfiguration,
                            origin: "https://example.com"
                        )
                        #expect(request.method == .POST)
                        #expect(request.headers["Content-Encoding"] == ["aes128gcm"])
                        #expect(request.headers["Content-Type"] == ["application/octet-stream"])
                        #expect(request.headers["TTL"] == ["2592000"])
                        #expect(request.headers["Urgency"] == ["high"])
                        #expect(request.headers["Topic"] == []) // TODO: Update when topic is added
                        
                        let message = try await decrypt(
                            request: request,
                            userAgentPrivateKey: subscriberPrivateKey,
                            userAgentKeyMaterial: subscriber.userAgentKeyMaterial
                        )
                        
                        #expect(String(decoding: message, as: UTF8.self) == #"{"hello":"world"}"#)
                        
                        requestWasMade()
                        return HTTPClientResponse(status: .created)
                    }))
                )
                
                try await manager.send(json: ["hello" : "world"], to: subscriber)
            }
        }
        
        @Test func sendMessageToNotFoundPushServerError() async throws {
            await confirmation { requestWasMade in
                let vapidConfiguration = VAPID.Configuration.makeTesting()
                
                let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
                var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
                for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
                
                let subscriber = Subscriber(
                    endpoint: URL(string: "https://example.com/subscriber")!,
                    userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
                    vapidKeyID: vapidConfiguration.primaryKey!.id
                )
                
                let manager = WebPushManager(
                    vapidConfiguration: vapidConfiguration,
                    backgroundActivityLogger: Logger(label: "WebPushManagerTests", factory: { PrintLogHandler(label: $0, metadataProvider: $1) }),
                    executor: .httpClient(MockHTTPClient({ request in
                        requestWasMade()
                        return HTTPClientResponse(status: .notFound)
                    }))
                )
                
                await #expect(throws: BadSubscriberError()) {
                    try await manager.send(string: "hello", to: subscriber)
                }
            }
        }
        
        @Test func sendMessageToGonePushServerError() async throws {
            await confirmation { requestWasMade in
                let vapidConfiguration = VAPID.Configuration.makeTesting()
                
                let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
                var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
                for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
                
                let subscriber = Subscriber(
                    endpoint: URL(string: "https://example.com/subscriber")!,
                    userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
                    vapidKeyID: vapidConfiguration.primaryKey!.id
                )
                
                let manager = WebPushManager(
                    vapidConfiguration: vapidConfiguration,
                    backgroundActivityLogger: Logger(label: "WebPushManagerTests", factory: { PrintLogHandler(label: $0, metadataProvider: $1) }),
                    executor: .httpClient(MockHTTPClient({ request in
                        requestWasMade()
                        return HTTPClientResponse(status: .gone)
                    }))
                )
                
                await #expect(throws: BadSubscriberError()) {
                    try await manager.send(string: "hello", to: subscriber)
                }
            }
        }
        
        @Test func sendMessageToUnknownPushServerError() async throws {
            await confirmation { requestWasMade in
                let vapidConfiguration = VAPID.Configuration.makeTesting()
                
                let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
                var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
                for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
                
                let subscriber = Subscriber(
                    endpoint: URL(string: "https://example.com/subscriber")!,
                    userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
                    vapidKeyID: vapidConfiguration.primaryKey!.id
                )
                
                let manager = WebPushManager(
                    vapidConfiguration: vapidConfiguration,
                    backgroundActivityLogger: Logger(label: "WebPushManagerTests", factory: { PrintLogHandler(label: $0, metadataProvider: $1) }),
                    executor: .httpClient(MockHTTPClient({ request in
                        requestWasMade()
                        return HTTPClientResponse(status: .internalServerError)
                    }))
                )
                
                await #expect(throws: HTTPError.self) {
                    try await manager.send(string: "hello", to: subscriber)
                }
            }
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

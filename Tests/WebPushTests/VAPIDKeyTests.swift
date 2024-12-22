//
//  VAPIDKeyTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-22.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Crypto
import Foundation
import Testing
@testable import WebPush
import WebPushTesting

@Suite("VAPID Key Tests") struct VAPIDKeyTests {
    @Suite struct Initialization {
        @Test func createNew() {
            let key = VAPID.Key()
            #expect(!key.id.description.isEmpty)
        }
        
        @Test func privateKey() {
            let privateKey = P256.Signing.PrivateKey()
            let key = VAPID.Key(privateKey: privateKey)
            #expect(key.id.description == privateKey.publicKey.x963Representation.base64URLEncodedString())
        }
        
        @Test func base64Representation() throws {
            let key = try VAPID.Key(base64URLEncoded: "6PSSAJiMj7uOvtE4ymNo5GWcZbT226c5KlV6c+8fx5g=")
            #expect(key.id.description == "BKO3ND8PZ4w3TMdjUE-VFLmwKoawWnfU_fHtp2G55mgOQdCY9sf2b9LjVbmItinpRPMC4qv_9GE9bSDYJ0jaErE")
            
            #expect(throws: Base64URLDecodingError()) {
                try VAPID.Key(base64URLEncoded: "()")
            }
            
            #expect(throws: CryptoKitError.self) {
                try VAPID.Key(base64URLEncoded: "AAAA")
            }
        }
    }
    
    @Test func equality() throws {
        let key1 = VAPID.Key.mockedKey1
        let key2 = VAPID.Key.mockedKey2
        let key3 = VAPID.Key(privateKey: try .init(rawRepresentation: Data(base64URLEncoded: "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=")!))
        
        #expect(key1 != key2)
        #expect(key1 == .mockedKey1)
        #expect(key1 == key3)
        #expect(key1.hashValue == key3.hashValue)
    }
    
    @Suite struct Coding {
        @Test func encoding() throws {
            #expect(String(decoding: try JSONEncoder().encode(VAPID.Key.mockedKey1), as: UTF8.self) == "\"FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=\"")
        }
        
        @Test func decoding() throws {
            #expect(try JSONDecoder().decode(VAPID.Key.self, from: Data("\"FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=\"".utf8)) == .mockedKey1)
            
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(VAPID.Key.self, from: Data("{}".utf8))
            }
            
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(VAPID.Key.self, from: Data("\"()\"".utf8))
            }
            
            #expect(throws: CryptoKitError.self) {
                try JSONDecoder().decode(VAPID.Key.self, from: Data("\"\"".utf8))
            }
            
            #expect(throws: CryptoKitError.self) {
                try JSONDecoder().decode(VAPID.Key.self, from: Data("\"AAAA\"".utf8))
            }
        }
    }
    
    @Suite struct Identification {
        @Test func comparable() {
            #expect([
                VAPID.Key.ID.mockedKeyID1,
                VAPID.Key.ID.mockedKeyID2,
                VAPID.Key.ID.mockedKeyID3,
                VAPID.Key.ID.mockedKeyID4,
            ].sorted() == [
                VAPID.Key.ID.mockedKeyID2,
                VAPID.Key.ID.mockedKeyID4,
                VAPID.Key.ID.mockedKeyID1,
                VAPID.Key.ID.mockedKeyID3,
            ])
        }
        
        @Test func encoding() throws {
            #expect(String(decoding: try JSONEncoder().encode(VAPID.Key.ID.mockedKeyID1), as: UTF8.self) == "\"BLf3RZAljlexEovBgfZgFTjcEVUKBDr3lIH8quJioMdX4FweRdId_P72h613ptxtU-qSAyW3Tbt_3WgwGhOUxrs\"")
        }
        
        @Test func decoding() throws {
            #expect(try JSONDecoder().decode(VAPID.Key.ID.self, from: Data("\"BLf3RZAljlexEovBgfZgFTjcEVUKBDr3lIH8quJioMdX4FweRdId_P72h613ptxtU-qSAyW3Tbt_3WgwGhOUxrs\"".utf8)) == .mockedKeyID1)
        }
    }
}

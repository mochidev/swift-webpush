//
//  VAPIDTokenTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-07.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Crypto
import Foundation
import Testing
@testable import WebPush

struct MockVAPIDKey<Bytes: ContiguousBytes & Sendable>: VAPIDKeyProtocol {
    var id: String
    var signature: Bytes
    
    func signature(for message: some DataProtocol) throws -> Bytes {
        signature
    }
}

@Suite struct VAPIDTokenTests {
    @Test func generatesValidSignedToken() throws {
        let key = VAPID.Key()
        
        let token = VAPID.Token(
            origin: "https://push.example.net",
            contactInformation: .email("push@example.com"),
            expiresIn: .hours(22)
        )
        
        let signedJWT = try token.generateJWT(signedBy: key)
        #expect(VAPID.Token(token: signedJWT, key: "\(key.id)") == token)
    }
    
    /// Make sure we can decode the example from https://datatracker.ietf.org/doc/html/rfc8292#section-2.4, as we use the same decoding logic to self-verify our own signing proceedure.
    @Test func tokenVerificationMatchesSpec() throws {
        var expectedToken = VAPID.Token(
            origin: "https://push.example.net",
            contactInformation: .email("push@example.com"),
            expiresIn: 0
        )
        expectedToken.expiration = 1453523768
        
        let receivedToken = VAPID.Token(
            token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiJ9.eyJhdWQiOiJodHRwczovL3B1c2guZXhhbXBsZS5uZXQiLCJleHAiOjE0NTM1MjM3NjgsInN1YiI6Im1haWx0bzpwdXNoQGV4YW1wbGUuY29tIn0.i3CYb7t4xfxCDquptFOepC9GAu_HLGkMlMuCGSK2rpiUfnK9ojFwDXb1JrErtmysazNjjvW2L9OkSSHzvoD1oA",
            key: "BA1Hxzyi1RUM1b5wjxsn7nGxAszw2u61m164i3MrAIxHF6YK5h4SDYic-dRuU_RCPCfA5aq9ojSwk5Y2EmClBPs"
        )
        #expect(receivedToken == expectedToken)
    }
    
    @Test func authorizationHeaderGeneration() throws {
        var expectedToken = VAPID.Token(
            origin: "https://push.example.net",
            contactInformation: .email("push@example.com"),
            expiresIn: 0
        )
        expectedToken.expiration = 1453523768
        
        let mockKey = MockVAPIDKey(
            id: "BA1Hxzyi1RUM1b5wjxsn7nGxAszw2u61m164i3MrAIxHF6YK5h4SDYic-dRuU_RCPCfA5aq9ojSwk5Y2EmClBPs",
            signature: Data(base64URLEncoded: "i3CYb7t4xfxCDquptFOepC9GAu_HLGkMlMuCGSK2rpiUfnK9ojFwDXb1JrErtmysazNjjvW2L9OkSSHzvoD1oA")!
        )
        
        let generatedHeader = try expectedToken.generateAuthorization(signedBy: mockKey)
        #expect(generatedHeader == "vapid t=eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiJ9.eyJhdWQiOiJodHRwczovL3B1c2guZXhhbXBsZS5uZXQiLCJleHAiOjE0NTM1MjM3NjgsInN1YiI6Im1haWx0bzpwdXNoQGV4YW1wbGUuY29tIn0.i3CYb7t4xfxCDquptFOepC9GAu_HLGkMlMuCGSK2rpiUfnK9ojFwDXb1JrErtmysazNjjvW2L9OkSSHzvoD1oA, k=BA1Hxzyi1RUM1b5wjxsn7nGxAszw2u61m164i3MrAIxHF6YK5h4SDYic-dRuU_RCPCfA5aq9ojSwk5Y2EmClBPs")
    }
}
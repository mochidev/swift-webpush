//
//  Base64URLCodingTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-06.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation
import Testing
@testable import WebPush

@Test func base64URLDecoding() async throws {
    let string              = ">>> Hello, swift-webpush world??? 🎉"
    let base64Encoded       = "Pj4+IEhlbGxvLCBzd2lmdC13ZWJwdXNoIHdvcmxkPz8/IPCfjok="
    let base64URLEncoded    = "Pj4-IEhlbGxvLCBzd2lmdC13ZWJwdXNoIHdvcmxkPz8_IPCfjok"
    #expect(String(decoding: Data(base64URLEncoded: base64Encoded)!, as: UTF8.self) == string)
    #expect(String(decoding: Data(base64URLEncoded: base64URLEncoded)!, as: UTF8.self) == string)
}

@Test func base64URLEncoding() async throws {
    let string              = ">>> Hello, swift-webpush world??? 🎉"
    let base64URLEncoded    = "Pj4-IEhlbGxvLCBzd2lmdC13ZWJwdXNoIHdvcmxkPz8_IPCfjok"
    #expect(Array(string.utf8).base64URLEncodedString() == base64URLEncoded)
}

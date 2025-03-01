//
//  NeverTests.swift
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

@Suite("Never Tests")
struct NeverTests {
    @Test func retroactiveCodableWorks() async throws {
        #expect(throws: DecodingError.self, performing: {
            try JSONDecoder().decode(Never.self, from: Data("null".utf8))
        })
    }
}

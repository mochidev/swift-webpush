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
//        struct CustomEncoder: Encoder {
//            var codingPath: [any CodingKey] = []
//            var userInfo: [CodingUserInfoKey : Any] = [:]
//            
//            func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
//                fatalError()
//            }
//            
//            func unkeyedContainer() -> any UnkeyedEncodingContainer {
//                fatalError()
//            }
//            
//            func singleValueContainer() -> any SingleValueEncodingContainer {
//                fatalError()
//            }
//        }
//        
//        struct DummyNever: Encodable {}
//        
//        let encodeFunction = unsafeBitCast(Never.encode, to: type(of: DummyNever.encode))
//        try encodeFunction(DummyNever())(CustomEncoder())
        
        #expect(throws: DecodingError.self, performing: {
            try JSONDecoder().decode(Never.self, from: Data("null".utf8))
        })
    }
}

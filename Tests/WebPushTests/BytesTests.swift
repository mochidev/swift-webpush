//
//  BytesTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-22.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation
import Testing
@testable import WebPush

@Suite struct BytesTests {
    @Test func stringBytes() {
        #expect("hello".utf8Bytes == [0x68, 0x65, 0x6c, 0x6c, 0x6f])
        #expect("hello"[...].utf8Bytes == [0x68, 0x65, 0x6c, 0x6c, 0x6f])
    }
    
    @Test func integerBytes() {
        #expect(UInt8(0b11110000).bigEndianBytes == [0b11110000])
        #expect(UInt16(0b1111000010100101).bigEndianBytes == [0b11110000, 0b10100101])
        #expect(UInt32(0b11110000101001010000111101011010).bigEndianBytes == [0b11110000, 0b10100101, 0b000001111, 0b01011010])
        #expect(UInt64(0b1111000010100101000011110101101011001100100011110011001101110000).bigEndianBytes == [0b11110000, 0b10100101, 0b000001111, 0b01011010, 0b11001100, 0b10001111, 0b00110011, 0b01110000])
    }
}

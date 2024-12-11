//
//  FixedWidthInteger+BigEndienBytes.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-11.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

extension FixedWidthInteger {
    /// The big endian representation of the integer.
    @usableFromInline
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}

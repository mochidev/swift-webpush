//
//  StringProtocol+UTF8Bytes.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-11.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

extension String {
    /// The UTF8 byte representation of the string.
    @usableFromInline
    var utf8Bytes: [UInt8] {
        var string = self
        return string.withUTF8 { Array($0) }
    }
}

extension Substring {
    /// The UTF8 byte representation of the string.
    @usableFromInline
    var utf8Bytes: [UInt8] {
        var string = self
        return string.withUTF8 { Array($0) }
    }
}

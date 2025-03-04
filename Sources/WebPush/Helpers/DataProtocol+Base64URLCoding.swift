//
//  DataProtocol+Base64URLCoding.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-06.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension DataProtocol {
    /// The receiver as a Base64 URL encoded string.
    @_disfavoredOverload
    @usableFromInline
    func base64URLEncodedString() -> String {
        Data(self)
            .base64EncodedString()
            .transformToBase64URLEncoding()
    }
}

extension String {
    /// Transform a regular Base64 encoded string to a Base64URL encoded one.
    @usableFromInline
    func transformToBase64URLEncoding() -> String {
        self.replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension ContiguousBytes {
    /// The receiver as a Base64 URL encoded string.
    @usableFromInline
    func base64URLEncodedString() -> String {
        withUnsafeBytes { bytes in
            (bytes as any DataProtocol).base64URLEncodedString()
        }
    }
}

extension DataProtocol where Self: RangeReplaceableCollection {
    /// Initialize data using a Base64 URL encoded string.
    @usableFromInline
    init?(base64URLEncoded string: some StringProtocol) {
        var base64String = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64String.count % 4 != 0 {
            base64String = base64String.appending("=")
        }
        
        guard let decodedData = Data(base64Encoded: base64String)
        else { return nil }
        
        self = Self(decodedData)
    }
}

//
//  DataProtocol+Base64URLCoding.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-06.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

extension DataProtocol {
    func base64URLEncodedString() -> String {
        Data(self)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension DataProtocol where Self: RangeReplaceableCollection {
    init?(base64URLEncoded string: String) {
        var base64String = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64String.count % 4 != 0 {
            base64String = base64String.appending("=")
        }
        
        guard let decodedData = Data(base64Encoded: base64String)
        else { return nil }
        
        self = Self(decodedData)
    }
}

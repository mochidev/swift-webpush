//
//  VAPIDKey.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-04.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
import Foundation

extension VoluntaryApplicationServerIdentification {
    public struct Key: Sendable {
        private var privateKey: P256.Signing.PrivateKey
        
        public init() {
            privateKey = P256.Signing.PrivateKey(compactRepresentable: false)
        }
        
        public init(privateKey: P256.Signing.PrivateKey) {
            self.privateKey = privateKey
        }
    }
}

extension VAPID.Key: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.privateKey.rawRepresentation == rhs.privateKey.rawRepresentation
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(privateKey.rawRepresentation)
    }
}

extension VAPID.Key: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        privateKey = try P256.Signing.PrivateKey(rawRepresentation: container.decode(Data.self))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(privateKey.rawRepresentation)
    }
}

extension VAPID.Key: Identifiable {
    public struct ID: Hashable, Comparable, Codable, Sendable {
        private var rawValue: String
        
        init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.rawValue = try container.decode(String.self)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
    }
    
    public var id: ID {
        ID(privateKey.publicKey.x963Representation.base64URLEncodedString())
    }
}

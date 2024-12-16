//
//  VAPIDToken.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-07.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
import Foundation

extension VAPID {
    /// An internal representation the token and authorization headers used self-identification.
    ///
    /// - SeeAlso: [RFC 8292 Voluntary Application Server Identification (VAPID) for Web Push §2. Application Server Self-Identification](https://datatracker.ietf.org/doc/html/rfc8292#section-2)
    struct Token: Hashable, Codable, Sendable {
        enum CodingKeys: String, CodingKey {
            case audience = "aud"
            case subject = "sub"
            case expiration = "exp"
        }
        
        var audience: String
        var subject: VAPID.Configuration.ContactInformation
        var expiration: Int
        
        static let jwtHeader = Array(#"{"typ":"JWT","alg":"ES256"}"#.utf8).base64URLEncodedString()
        
        init(
            origin: String,
            contactInformation: VAPID.Configuration.ContactInformation,
            expiration: Date
        ) {
            self.audience = origin
            self.subject = contactInformation
            self.expiration = Int(expiration.timeIntervalSince1970)
        }
        
        init(
            origin: String,
            contactInformation: VAPID.Configuration.ContactInformation,
            expiresIn: VAPID.Configuration.Duration
        ) {
            audience = origin
            subject = contactInformation
            expiration = Int(Date.now.timeIntervalSince1970) + expiresIn.seconds
        }
        
        init?(token: String, key: String) {
            let components = token.split(separator: ".")
            
            guard
                components.count == 3,
                components[0] == Self.jwtHeader,
                let bodyBytes = Data(base64URLEncoded: components[1]),
                let signatureBytes = Data(base64URLEncoded: components[2]),
                let publicKeyBytes = Data(base64URLEncoded: key)
            else { return nil }
            
            let message = Data("\(components[0]).\(components[1])".utf8)
            let publicKey = try? P256.Signing.PublicKey(x963Representation: publicKeyBytes)
            let isValid = try? publicKey?.isValidSignature(.init(rawRepresentation: signatureBytes), for: SHA256.hash(data: message))
            
            guard
                isValid == true,
                let token = try? JSONDecoder().decode(Self.self, from: bodyBytes)
            else { return nil }
            
            self = token
        }
        
        func generateJWT(signedBy signingKey: some VAPIDKeyProtocol) throws -> String {
            let header = Self.jwtHeader
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let body = try encoder.encode(self).base64URLEncodedString()
            
            var message = "\(header).\(body)"
            let signature = try message.withUTF8 { try signingKey.signature(for: $0) }.base64URLEncodedString()
            return "\(message).\(signature)"
        }
        
        func generateAuthorization(signedBy signingKey: some VAPIDKeyProtocol) throws -> String {
            let token = try generateJWT(signedBy: signingKey)
            let key = signingKey.id
            
            return "vapid t=\(token), k=\(key)"
        }
    }
}

protocol VAPIDKeyProtocol: Identifiable, Sendable {
    associatedtype Signature: ContiguousBytes
    
    func signature(for message: some DataProtocol) throws -> Signature
}

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
    /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2. Application Server Self-Identification](https://datatracker.ietf.org/doc/html/rfc8292#section-2)
    /// - SeeAlso: [RFC 7515 — JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515)
    ///- SeeAlso: [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
    struct Token: Hashable, Codable, Sendable {
        /// The coding keys used to encode the token.
        enum CodingKeys: String, CodingKey {
            case audience = "aud"
            case subject = "sub"
            case expiration = "exp"
        }
        
        /// The audience claim, which encodes the origin of the ``Subscriber/endpoint``
        ///
        /// - SeeAlso: ``/Foundation/URL/origin``
        /// - SeeAlso: [RFC 7519 — JSON Web Token (JWT) §4.1.3. "aud" (Audience) Claim](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3)
        /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2. Application Server Self-Identification](https://datatracker.ietf.org/doc/html/rfc8292#section-2)
        var audience: String
        
        /// The subject claim, which encodes contact information for the application server.
        ///
        /// - SeeAlso: [RFC 7519 — JSON Web Token (JWT) §4.1.2. "sub" (Subject) Claim](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.2)
        /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2.1. Application Server Contact Information](https://datatracker.ietf.org/doc/html/rfc8292#section-2.1)
        var subject: Configuration.ContactInformation
        
        /// The expiry claim, which encodes the number of seconds after 1970/01/01 when the token expires.
        ///
        /// - SeeAlso: [RFC 7519 — JSON Web Token (JWT) §4.1.4. "exp" (Expiration Time) Claim](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.4)
        /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2. Application Server Self-Identification](https://datatracker.ietf.org/doc/html/rfc8292#section-2)
        var expiration: Int
        
        /// The standard header including the type and algorithm.
        ///
        /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2. Application Server Self-Identification](https://datatracker.ietf.org/doc/html/rfc8292#section-2)
        static let jwtHeader = Array(#"{"typ":"JWT","alg":"ES256"}"#.utf8).base64URLEncodedString()
        
        /// Initialize a token with the specified claims.
        init(
            origin: String,
            contactInformation: Configuration.ContactInformation,
            expiration: Date
        ) {
            self.audience = origin
            self.subject = contactInformation
            self.expiration = Int(expiration.timeIntervalSince1970)
        }
        
        /// Initialize a token with the specified claims.
        init(
            origin: String,
            contactInformation: Configuration.ContactInformation,
            expiresIn: Configuration.Duration
        ) {
            audience = origin
            subject = contactInformation
            expiration = Int(Date.now.timeIntervalSince1970) + expiresIn.seconds
        }
        
        /// Initialize a token from a VAPID `Authorization` header's values.
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
        
        /// - SeeAlso: [RFC 7515 — JSON Web Signature (JWS) §3. JSON Web Signature (JWS) Overview](https://datatracker.ietf.org/doc/html/rfc7515#section-3)
        func generateJWT(signedBy signingKey: some VAPIDKeyProtocol) throws -> String {
            let header = Self.jwtHeader
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let body = try encoder.encode(self).base64URLEncodedString()
            
            var message = "\(header).\(body)"
            let signature = try message.withUTF8 { try signingKey.signature(for: $0) }.base64URLEncodedString()
            return "\(message).\(signature)"
        }
        
        /// Generate an `Authorization` header.
        ///
        /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §3. VAPID Authentication Scheme](https://datatracker.ietf.org/doc/html/rfc8292#section-3)
        func generateAuthorization(signedBy signingKey: some VAPIDKeyProtocol) throws -> String {
            let token = try generateJWT(signedBy: signingKey)
            let key = signingKey.id
            
            return "vapid t=\(token), k=\(key)"
        }
    }
}

protocol VAPIDKeyProtocol: Identifiable, Sendable {
    /// The signature type used by this key.
    associatedtype Signature: ContiguousBytes
    
    /// Returns a JWS signature for the message.
    /// - SeeAlso: [RFC 7515 — JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515)
    func signature(for message: some DataProtocol) throws -> Signature
}

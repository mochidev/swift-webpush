//
//  SubscriberTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-21.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Crypto
import Foundation
import Testing
@testable import WebPush
import WebPushTesting

@Suite struct SubscriberTests {
    @Suite struct Initialization {
        @Test func fromKeyMaterial() {
            let privateKey = P256.KeyAgreement.PrivateKey()
            let subscriber = Subscriber(
                endpoint: URL(string: "https://example.com/subscriber")!,
                userAgentKeyMaterial: UserAgentKeyMaterial(
                    publicKey: privateKey.publicKey,
                    authenticationSecret: Data()
                ),
                vapidKeyID: .mockedKeyID1
            )
            #expect(subscriber.endpoint == URL(string: "https://example.com/subscriber")!)
            #expect(subscriber.userAgentKeyMaterial == UserAgentKeyMaterial(
                publicKey: privateKey.publicKey,
                authenticationSecret: Data()
            ))
            #expect(subscriber.vapidKeyID == .mockedKeyID1)
        }
        
        @Test func fromOtherSubscriber() {
            let subscriber = Subscriber(.mockedSubscriber())
            #expect(subscriber == .mockedSubscriber)
        }
        
        @Test func identifiable() {
            let subscriber = Subscriber.mockedSubscriber
            #expect(subscriber.id == "https://example.com/subscriber")
        }
    }
    
    @Suite struct UserAgentKeyMaterialTests {
        @Suite struct Initialization {
            @Test func actualKeys() {
                let privateKey = P256.KeyAgreement.PrivateKey()
                let keyMaterial = UserAgentKeyMaterial(
                    publicKey: privateKey.publicKey,
                    authenticationSecret: Data()
                )
                #expect(keyMaterial == UserAgentKeyMaterial(
                    publicKey: privateKey.publicKey,
                    authenticationSecret: Data()
                ))
            }
            
            @Test func strings() throws {
                let privateKey = UserAgentKeyMaterial.mockedKeyMaterialPrivateKey
                let keyMaterial = try UserAgentKeyMaterial(
                    publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M",
                    authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                )
                
                #expect(keyMaterial == UserAgentKeyMaterial(
                    publicKey: privateKey.publicKey,
                    authenticationSecret: keyMaterial.authenticationSecret
                ))
                
                #expect(throws: UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError())) {
                    try UserAgentKeyMaterial(
                        publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M",
                        authenticationSecret: "()"
                    )
                }
                
                #expect(throws: UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError())) {
                    try UserAgentKeyMaterial(
                        publicKey: "()",
                        authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                    )
                }
                
                #expect(throws: UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError())) {
                    try UserAgentKeyMaterial(
                        publicKey: "()",
                        authenticationSecret: "()"
                    )
                }
                
                #expect(throws: UserAgentKeyMaterialError.invalidPublicKey(underlyingError: CryptoKitError.incorrectParameterSize)) {
                    try UserAgentKeyMaterial(
                        publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYM",
                        authenticationSecret: "()"
                    )
                }
            }
            
            @Test func hashes() throws {
                let keyMaterial1 = try UserAgentKeyMaterial(
                    publicKey: "BPgjN_Qet3SrCclnXNri-jEHu31CsdeZmNH9xkNskR58jBpxcqXJFspAPBeahlvNqUVXvorTn9RKcXag_esAmG0",
                    authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                )
                let keyMaterial2 = try UserAgentKeyMaterial(
                    publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M",
                    authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                )
                var set: Set = [keyMaterial1, keyMaterial2]
                #expect(set.count == 2)
                set.insert(try UserAgentKeyMaterial(
                    publicKey: "BPgjN_Qet3SrCclnXNri-jEHu31CsdeZmNH9xkNskR58jBpxcqXJFspAPBeahlvNqUVXvorTn9RKcXag_esAmG0",
                    authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                ))
                #expect(set.count == 2)
                set.insert(try UserAgentKeyMaterial(
                    publicKey: "BPgjN_Qet3SrCclnXNri-jEHu31CsdeZmNH9xkNskR58jBpxcqXJFspAPBeahlvNqUVXvorTn9RKcXag_esAmG0",
                    authenticationSecret: "AzODAQZN6BbGvmm7vWQJXg"  // first character: A
                ))
                #expect(set.count == 3)
            }
        }
        
        @Suite struct Coding {
            @Test func encodes() async throws {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let result = String(
                    decoding: try encoder.encode(UserAgentKeyMaterial(
                        publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M",
                        authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                    )),
                    as: UTF8.self
                )
                
                #expect(result == """
                {
                  "auth" : "IzODAQZN6BbGvmm7vWQJXg",
                  "p256dh" : "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M"
                }
                """)
            }
            
            @Test func decodes() async throws {
                #expect(
                    try JSONDecoder().decode(UserAgentKeyMaterial.self, from: Data("""
                        {
                          "auth" : "IzODAQZN6BbGvmm7vWQJXg",
                          "p256dh" : "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M"
                        }
                        """.utf8
                    )) ==
                    UserAgentKeyMaterial(
                        publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M",
                        authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
                    )
                )
                
                #expect(throws: UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError())) {
                    try JSONDecoder().decode(UserAgentKeyMaterial.self, from: Data("""
                        {
                          "auth" : "()",
                          "p256dh" : "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M"
                        }
                        """.utf8
                    ))
                }
                
                #expect(throws: UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError())) {
                    try JSONDecoder().decode(UserAgentKeyMaterial.self, from: Data("""
                        {
                          "auth" : "IzODAQZN6BbGvmm7vWQJXg",
                          "p256dh" : "()"
                        }
                        """.utf8
                    ))
                }
                
                #expect(throws: UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError())) {
                    try JSONDecoder().decode(UserAgentKeyMaterial.self, from: Data("""
                        {
                          "auth" : "()",
                          "p256dh" : "()"
                        }
                        """.utf8
                    ))
                }
                
                /// `UserAgentKeyMaterialError.invalidPublicKey(underlyingError: CryptoKitError.incorrectParameterSize)` on macOS, `UserAgentKeyMaterialError.invalidPublicKey(underlyingError: CryptoKitError.underlyingCoreCryptoError(error: 251658360))` on Linux
                #expect(throws: UserAgentKeyMaterialError.self) {
                    try JSONDecoder().decode(UserAgentKeyMaterial.self, from: Data("""
                        {
                          "auth" : "IzODAQZN6BbGvmm7vWQJXg",
                          "p256dh" : "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1A"
                        }
                        """.utf8
                    ))
                }
            }
        }
    }
}

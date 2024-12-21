//
//  ErrorTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-21.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import AsyncHTTPClient
import Foundation
import Testing
@testable import WebPush

@Suite struct ErrorTests {
    @Test func badSubscriberError() {
        #expect(BadSubscriberError() == BadSubscriberError())
        #expect("\(BadSubscriberError().localizedDescription)" == "The subscription is no longer valid.")
    }
    
    @Test func base64URLDecodingError() {
        #expect(Base64URLDecodingError() == Base64URLDecodingError())
        #expect("\(Base64URLDecodingError().localizedDescription)" == "The Base64 data could not be decoded.")
    }
    
    @Test func httpError() {
        let response = HTTPClientResponse(status: .notFound)
        #expect(HTTPError(response: response) == HTTPError(response: response))
        #expect(HTTPError(response: response).hashValue == HTTPError(response: response).hashValue)
        #expect(HTTPError(response: response) != HTTPError(response: HTTPClientResponse(status: .internalServerError)))
        #expect("\(HTTPError(response: response).localizedDescription)" == "A 404 Not Found HTTP error was encountered: \(response).")
    }
    
    @Test func messageTooLargeError() {
        #expect(MessageTooLargeError() == MessageTooLargeError())
        #expect("\(MessageTooLargeError().localizedDescription)" == "The message was too large, and could not be delivered to the push service.")
    }
    
    @Test func userAgentKeyMaterialError() {
        #expect(UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError()) == .invalidPublicKey(underlyingError: Base64URLDecodingError()))
        #expect(UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError()).hashValue == UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError()).hashValue)
        #expect(UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError()) != .invalidPublicKey(underlyingError: BadSubscriberError()))
        #expect(UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()) == .invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()))
        #expect(UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()).hashValue == UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()).hashValue)
        #expect(UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()) != .invalidAuthenticationSecret(underlyingError: BadSubscriberError()))
        #expect(UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError()) != .invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()))

        #expect("\(UserAgentKeyMaterialError.invalidPublicKey(underlyingError: Base64URLDecodingError()).localizedDescription)" == "Subscriber Public Key (`p256dh`) was invalid: The Base64 data could not be decoded.")
        #expect("\(UserAgentKeyMaterialError.invalidAuthenticationSecret(underlyingError: Base64URLDecodingError()).localizedDescription)" == "Subscriber Authentication Secret (`auth`) was invalid: The Base64 data could not be decoded.")
    }
    
    @Test func vapidConfigurationError() {
        #expect(VAPID.ConfigurationError.keysNotProvided == .keysNotProvided)
        #expect(VAPID.ConfigurationError.matchingKeyNotFound == .matchingKeyNotFound)
        #expect(VAPID.ConfigurationError.keysNotProvided != .matchingKeyNotFound)
        #expect("\(VAPID.ConfigurationError.keysNotProvided.localizedDescription)" == "VAPID keys not found during initialization.")
        #expect("\(VAPID.ConfigurationError.matchingKeyNotFound.localizedDescription)" == "A VAPID key for the subscriber was not found.")
    }
}

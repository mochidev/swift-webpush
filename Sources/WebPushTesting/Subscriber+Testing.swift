//
//  Subscriber+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-20.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

@preconcurrency import Crypto
import Foundation
import WebPush

extension Subscriber {
    /// A mocked subscriber to send messages to.
    public static let mockedSubscriber = Subscriber(
        endpoint: URL(string: "https://example.com/subscriber")!,
        userAgentKeyMaterial: .mockedKeyMaterial,
        vapidKeyID: .mockedKeyID1
    )
    
    /// Make a mocked subscriber with a unique private key and salt.
    static func makeMockedSubscriber(endpoint: URL = URL(string: "https://example.com/subscriber")!) -> (subscriber: Subscriber, privateKey: P256.KeyAgreement.PrivateKey) {
        let subscriberPrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: false)
        var authenticationSecret: [UInt8] = Array(repeating: 0, count: 16)
        for index in authenticationSecret.indices { authenticationSecret[index] = .random(in: .min ... .max) }
        
        let subscriber = Subscriber(
            endpoint: endpoint,
            userAgentKeyMaterial: UserAgentKeyMaterial(publicKey: subscriberPrivateKey.publicKey, authenticationSecret: Data(authenticationSecret)),
            vapidKeyID: .mockedKeyID1
        )
        
        return (subscriber, subscriberPrivateKey)
    }
}

extension SubscriberProtocol where Self == Subscriber {
    /// A mocked subscriber to send messages to.
    public static func mockedSubscriber() -> Subscriber {
        .mockedSubscriber
    }
}

extension UserAgentKeyMaterial {
    /// The private key component of ``mockedKeyMaterial``.
    public static let mockedKeyMaterialPrivateKey = try! P256.KeyAgreement.PrivateKey(rawRepresentation: Data(base64Encoded: "BS2nTTf5wAdVvi5Om3AjSmlsCpz91XgK+uCLaIJ0T/M=")!)
    
    /// A mocked user-agent-key material to attach to a subscriber.
    public static let mockedKeyMaterial = try! UserAgentKeyMaterial(
        publicKey: "BMXVxJELqTqIqMka5N8ujvW6RXI9zo_xr5BQ6XGDkrsukNVPyKRMEEfzvQGeUdeZaWAaAs2pzyv1aoHEXYMtj1M",
        authenticationSecret: "IzODAQZN6BbGvmm7vWQJXg"
    )
}

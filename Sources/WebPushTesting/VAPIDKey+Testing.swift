//
//  VAPIDKey+Testing.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-18.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import WebPush

extension VAPID.Key {
    /// A mocked key guaranteed to not conflict with ``mockedKey2``, ``mockedKey3``, and ``mockedKey4``.
    public static let mockedKey1 = try! VAPID.Key(base64URLEncoded: "FniTgSrf0l+BdfeC6LiblKXBbY4LQm0S+4STNCoJI+0=")
    /// A mocked key guaranteed to not conflict with ``mockedKey1``, ``mockedKey3``, and ``mockedKey4``.
    public static let mockedKey2 = try! VAPID.Key(base64URLEncoded: "wyQaGWNwvXKzVmPIhkqVQvQ+FKx1SNqHJ+re8n2ORrk=")
    /// A mocked key guaranteed to not conflict with ``mockedKey1``, ``mockedKey2``, and ``mockedKey4``.
    public static let mockedKey3 = try! VAPID.Key(base64URLEncoded: "bcZgo/p2WFqXaKFzmYaDKO/gARjWvGi3oXyHM2QNlfE=")
    /// A mocked key guaranteed to not conflict with ``mockedKey1``, ``mockedKey2``, and ``mockedKey3``.
    public static let mockedKey4 = try! VAPID.Key(base64URLEncoded: "BGEhWik09/s/JNkl0OAcTIdRTb7AoLRZQQG4C96Ohlc=")
}

extension VAPID.Key.ID {
    /// A mocked key ID that matches ``/VAPID/Key/mockedKey1``.
    public static let mockedKeyID1 = VAPID.Key.mockedKey1.id
    /// A mocked key ID that matches ``/VAPID/Key/mockedKey2``.
    public static let mockedKeyID2 = VAPID.Key.mockedKey2.id
    /// A mocked key ID that matches ``/VAPID/Key/mockedKey3``.
    public static let mockedKeyID3 = VAPID.Key.mockedKey3.id
    /// A mocked key ID that matches ``/VAPID/Key/mockedKey4``.
    public static let mockedKeyID4 = VAPID.Key.mockedKey4.id
}

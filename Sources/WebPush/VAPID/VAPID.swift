//
//  VAPIDKey.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-03.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The fully qualified name for VAPID.
public typealias VoluntaryApplicationServerIdentification = VAPID

/// A set of types for Voluntary Application Server Identification, also known as VAPID.
///
/// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push](https://datatracker.ietf.org/doc/html/rfc8292)
public enum VAPID: Sendable {}

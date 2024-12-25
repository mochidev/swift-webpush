//
//  URL+Origin.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-09.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import Foundation

extension URL {
    /// Returns the origin for the receiving URL, as defined for use in signing headers for VAPID.
    ///
    /// This implementation is similar to the [WHATWG Standard](https://url.spec.whatwg.org/#concept-url-origin), except that it uses the unicode form of the host, and is limited to HTTP and HTTPS schemas.
    ///
    /// - SeeAlso: [RFC 8292 — Voluntary Application Server Identification (VAPID) for Web Push §2. Application Server Self-Identification](https://datatracker.ietf.org/doc/html/rfc8292#section-2)
    /// - SeeAlso: [RFC 6454 — The Web Origin Concept §6.1. Unicode Serialization of an Origin](https://datatracker.ietf.org/doc/html/rfc6454#section-6.1)
    var origin: String {
        /// Note that we need the unicode variant, which only URLComponents provides.
        let components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        guard
            let scheme = components?.scheme?.lowercased(),
            let host = components?.host
        else { return "null" }
        
        switch scheme {
        case "http":
            let port = components?.port ?? 80
            return "http://" + host + (port != 80 ? ":\(port)" : "")
        case "https":
            let port = components?.port ?? 443
            return "https://" + host + (port != 443 ? ":\(port)" : "")
        default: return "null"
        }
    }
}

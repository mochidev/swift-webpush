//
//  URLOriginTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-22.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable import WebPush

@Suite struct URLOriginTests {
    @Test func httpURLs() {
        #expect(URL(string: "http://example.com/subscriber")?.origin == "http://example.com")
        #expect(URL(string: "http://example.com/")?.origin == "http://example.com")
        #expect(URL(string: "http://example.com")?.origin == "http://example.com")
        #expect(URL(string: "HtTp://Example.com/")?.origin == "http://Example.com")
        #expect(URL(string: "http://example.com:80/")?.origin == "http://example.com")
        #expect(URL(string: "http://example.com:8081/")?.origin == "http://example.com:8081")
        #expect(URL(string: "http://example.com:443/")?.origin == "http://example.com:443")
        #expect(URL(string: "http://host/")?.origin == "http://host")
        #expect(URL(string: "http://user:pass@host/")?.origin == "http://host")
        #expect(URL(string: "http://")?.origin == "http://")
        #expect(URL(string: "http:///")?.origin == "http://")
        #expect(URL(string: "http://じぃ.app/")?.origin == "http://じぃ.app")
        #expect(URL(string: "http://xn--m8jyb.app/")?.origin == "http://じぃ.app")
    }
    
    @Test func httpsURLs() {
        #expect(URL(string: "https://example.com/subscriber")?.origin == "https://example.com")
        #expect(URL(string: "https://example.com/")?.origin == "https://example.com")
        #expect(URL(string: "https://example.com")?.origin == "https://example.com")
        #expect(URL(string: "HtTps://Example.com/")?.origin == "https://Example.com")
        #expect(URL(string: "https://example.com:443/")?.origin == "https://example.com")
        #expect(URL(string: "https://example.com:4443/")?.origin == "https://example.com:4443")
        #expect(URL(string: "https://example.com:80/")?.origin == "https://example.com:80")
        #expect(URL(string: "https://host/")?.origin == "https://host")
        #expect(URL(string: "https://user:pass@host/")?.origin == "https://host")
        #expect(URL(string: "https://")?.origin == "https://")
        #expect(URL(string: "https:///")?.origin == "https://")
        #expect(URL(string: "https://じぃ.app/")?.origin == "https://じぃ.app")
        #expect(URL(string: "https://xn--m8jyb.app/")?.origin == "https://じぃ.app")
    }
    
    @Test func otherURLs() {
        #expect(URL(string: "file://example.com/subscriber")?.origin == "null")
        #expect(URL(string: "ftp://example.com/")?.origin == "null")
        #expect(URL(string: "blob:example.com")?.origin == "null")
        #expect(URL(string: "mailto:test@example.com")?.origin == "null")
        #expect(URL(string: "example.com")?.origin == "null")
        #expect(URL(string: "otherFile.html")?.origin == "null")
        #expect(URL(string: "/subscriber")?.origin == "null")
    }
}

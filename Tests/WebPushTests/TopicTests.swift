//
//  TopicTests.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-24.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//


import Crypto
import Foundation
import Testing
@testable import WebPush

extension Character {
    var isBase64URLSafe: Bool {
        self.isASCII && (
            self.isLetter
            || self.isNumber
            || self == "-"
            || self == "_"
        )
    }
}

@Suite struct TopicTests {
    @Test func topicIsValid() throws {
        func checkValidity(_ topic: String) {
            #expect(topic.count == 32)
            let allSafeCharacters = topic.allSatisfy(\.isBase64URLSafe)
            #expect(allSafeCharacters)
        }
        checkValidity(try Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes).topic)
        checkValidity(try Topic(encodableTopic: "", salt: "Salty".utf8Bytes).topic)
        checkValidity(try Topic(encodableTopic: "", salt: "".utf8Bytes).topic)
        checkValidity(try Topic(encodableTopic: ["A", "B", "C"], salt: "SecretSalt".utf8Bytes).topic)
        checkValidity(try Topic(encodableTopic: ["a" : "b"], salt: "SecretSalt".utf8Bytes).topic)
        checkValidity(try Topic(encodableTopic: UUID(), salt: "SecretSalt".utf8Bytes).topic)
        checkValidity(Topic().topic)
        
        struct ComplexTopic: Codable {
            var user = "Dimitri"
            var app = "Jiiiii"
            var id = UUID()
            var secretNumber = 42
        }
        checkValidity(try Topic(encodableTopic: ComplexTopic(), salt: "SecretSalt".utf8Bytes).topic)
        
        do {
            let unsafeTopic = Topic(unsafeTopic: "test")
            #expect(unsafeTopic.topic.count != 32)
            let allSafeCharacters = unsafeTopic.topic.allSatisfy(\.isBase64URLSafe)
            #expect(allSafeCharacters)
        }
        do {
            let unsafeTopic = Topic(unsafeTopic: "()")
            #expect(unsafeTopic.topic.count != 32)
            let allSafeCharacters = unsafeTopic.topic.allSatisfy(\.isBase64URLSafe)
            #expect(!allSafeCharacters)
        }
    }
    
    @Test func topicIsTransformed() throws {
        #expect(try Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes).topic == "mwgQxrwapKl47ipX1F8Rc84rcd2ve3M-")
        #expect(Topic(unsafeTopic: "test").topic == "test")
        #expect(Topic(unsafeTopic: "A really long test (with unsafe characters to boot ふふふ!)").topic == "A really long test (with unsafe characters to boot ふふふ!)")
    }
    
    @Test func topicIsDescribable() throws {
        #expect("\(try Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes))" == "mwgQxrwapKl47ipX1F8Rc84rcd2ve3M-")
        #expect("\(Topic(unsafeTopic: "test"))" == "test")
        #expect("\(Topic(unsafeTopic: "A really long test (with unsafe characters to boot ふふふ!)"))" == "A really long test (with unsafe characters to boot ふふふ!)")
    }
    
    @Test func transformsDeterministically() throws {
        #expect(try Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes) == Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes))
        #expect(try Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes) != Topic(encodableTopic: "Hello", salt: "NotSalty".utf8Bytes))
        #expect(try Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes) != Topic(encodableTopic: "Hello, World", salt: "Salty".utf8Bytes))
    }
    
    @Suite struct Coding {
        @Test func encoding() throws {
            #expect(String(decoding: try JSONEncoder().encode(Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes)), as: UTF8.self) == "\"mwgQxrwapKl47ipX1F8Rc84rcd2ve3M-\"")
        }
        
        @Test func decoding() throws {
            #expect(try JSONDecoder().decode(Topic.self, from: Data("\"mwgQxrwapKl47ipX1F8Rc84rcd2ve3M-\"".utf8)) == Topic(encodableTopic: "Hello", salt: "Salty".utf8Bytes))
            
            #expect(try JSONDecoder().decode(Topic.self, from: Data("\"test\"".utf8)) == Topic(unsafeTopic: "test"))
            
            #expect(try JSONDecoder().decode(Topic.self, from: Data("\"A really long test (with unsafe characters to boot ふふふ!)\"".utf8)) == Topic(unsafeTopic: "A really long test (with unsafe characters to boot ふふふ!)"))
            
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(Topic.self, from: Data("{}".utf8))
            }
        }
    }
}

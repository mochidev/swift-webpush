//
//  VAPIDKeyGenerator.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-14.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

import ArgumentParser
import Foundation
import WebPush

@main
struct MyCoolerTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate VAPID Keys.",
        usage: """
            vapid-key-generator <support-url>
            vapid-key-generator --email <email>
            vapid-key-generator --key-only
            """,
        discussion: """
            Generates VAPID keys and configurations suitable for use on your server. Keys should generally only be generated once and kept secure.
            """
    )
    
    @Flag(name: [.long, .customShort("k")], help: "Only generate a VAPID key.")
    var keyOnly = false
    
    @Flag(name: [.long, .customShort("s")], help: "Output raw JSON only so this tool can be piped with others in scripts.")
    var silent = false
    
    @Flag(name: [.long, .customShort("p")], help: "Output JSON with spacing. Has no effect when generating keys only.")
    var pretty = false
    
    @Option(name: [.long], help: "Parse the input as an email address.")
    var email: String?
    
    @Argument(help: "The fully-qualified HTTPS support URL administrators of push services may contact you at: https://example.com/support") var supportURL: URL?
    
    mutating func run() throws {
        let key = VAPID.Key()
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys, .prettyPrinted]
        } else {
            encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        }
        
        if keyOnly, supportURL == nil, email == nil {
            let json = String(decoding: try encoder.encode(key), as: UTF8.self)
            
            if silent {
                print("\(json)")
            } else {
                print("VAPID.Key: \(json)\n\n")
                print("Example Usage:")
                print("    // TODO: Load this data from .env or from file system")
                print("    let keyData = Data(\(json).utf8)")
                print("    let vapidKey = try VAPID.Key(base64URLEncoded: keyData)")
            }
        } else if !keyOnly {
            let contactInformation = if let supportURL, email == nil {
                VAPID.Configuration.ContactInformation.url(supportURL)
            } else if supportURL == nil, let email {
                VAPID.Configuration.ContactInformation.email(email)
            } else if supportURL != nil, email != nil {
                throw UnknownError(reason: "Only one of an email or a support-url may be specified.")
            } else {
                throw UnknownError(reason: "A valid support-url must be specified.")
            }
            if let supportURL {
                guard let scheme = supportURL.scheme?.lowercased(), scheme == "http" || scheme == "https"
                else { throw UnknownError(reason: "support-url must be an HTTP or HTTPS.") }
            }
            
            let configuration = VAPID.Configuration(key: key, contactInformation: contactInformation)
            
            let json = String(decoding: try encoder.encode(configuration), as: UTF8.self)
            
            if silent {
                print("\(json)")
            } else {
                var exampleJSON = ""
                if pretty {
                    print("VAPID.Configuration:\n\(json)\n\n")
                    exampleJSON = json
                    exampleJSON.replace("\n", with: "\n        ")
                    exampleJSON = "#\"\"\"\n        \(exampleJSON)\n        \"\"\"#"
                } else {
                    print("VAPID.Configuration: \(json)\n\n")
                    exampleJSON = "#\" \(json) \"#"
                }
                print("Example Usage:")
                print("    // TODO: Load this data from .env or from file system")
                print("    let configurationData = Data(\(exampleJSON).utf8)")
                print("    let vapidConfiguration = try JSONDecoder().decode(VAPID.Configuration.self, from: configurationData)")
            }
        } else {
            if email != nil {
                throw UnknownError(reason: "An email cannot be specified if only keys are being generated.")
            } else {
                throw UnknownError(reason: "A support-url cannot be specified if only keys are being generated.")
            }
        }
    }
}

struct UnknownError: LocalizedError {
    var reason: String
    
    var errorDescription: String? { reason }
}

extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(string: argument)
    }
}

//
//  PrintLogHandler.swift
//  swift-webpush
//
//  Created by Dimitri Bouniol on 2024-12-06.
//  Copyright © 2024 Mochi Development, Inc. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging

/// A simple log handler that uses formatted print statements.
package struct PrintLogHandler: LogHandler {
    private let label: String

    package var logLevel: Logger.Level = .info
    package var metadataProvider: Logger.MetadataProvider?
    
    package init(
        label: String,
        logLevel: Logger.Level = .info,
        metadataProvider: Logger.MetadataProvider? = nil
    ) {
        self.label = label
        self.logLevel = logLevel
        self.metadataProvider = metadataProvider
    }

    private var prettyMetadata: String?
    package var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    package subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    package func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let effectiveMetadata = Self.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: explicitMetadata
        )

        let prettyMetadata: String?
        if let effectiveMetadata = effectiveMetadata {
            prettyMetadata = self.prettify(effectiveMetadata)
        } else {
            prettyMetadata = self.prettyMetadata
        }

        print("\(self.timestamp()) [\(level)] \(self.label):\(prettyMetadata.map { " \($0)" } ?? "") [\(source)] \(message)")
    }

    private static func prepareMetadata(
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?
    ) -> Logger.Metadata? {
        var metadata = base

        let provided = provider?.get() ?? [:]

        guard !provided.isEmpty || !((explicit ?? [:]).isEmpty) else {
            // all per-log-statement values are empty
            return nil
        }

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        return metadata
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        if metadata.isEmpty {
            return nil
        } else {
            return metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
        }
    }

    private func timestamp() -> String {
        Date().formatted(date: .numeric, time: .complete)
    }
}

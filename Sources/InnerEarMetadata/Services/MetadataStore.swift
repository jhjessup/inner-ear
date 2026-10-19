import Foundation
import InnerEarCore

/// Persistence layer for `RecordingMetadata`. All data is stored as JSON
/// files under `~/Library/Application Support/InnerEar/metadata/`, same
/// one-JSON-file-per-UUID pattern as `RecordingStore`/`TranscriptStore`.
///
/// Exposes `listAll()` only, not a `load(forRecording:)` lookup — matches
/// how `TUIRunLoop.buildRecordingListEntries` already joins
/// `Recording`/`Transcript`/`Summary` by linear-scanning a `listX()` result
/// rather than each store exposing its own by-foreign-key lookup.
public final class MetadataStore: Sendable {
    private let disk: JSONDiskStore
    private static let subdirectory = "metadata"

    public init() throws {
        let base = InnerEarConfigResolver.resolveDataDirectory()
        self.disk = try JSONDiskStore(baseDirectory: base, subdirectories: [Self.subdirectory])
    }

    public func save(_ metadata: RecordingMetadata) throws {
        try disk.write(metadata, to: disk.fileURL(subdirectory: Self.subdirectory, id: metadata.id))
    }

    /// All persisted metadata entries, most recently captured first.
    public func listAll() throws -> [RecordingMetadata] {
        let files = try disk.listFiles(in: Self.subdirectory)
        let entries: [RecordingMetadata] = files.compactMap { disk.decodeOrWarn(RecordingMetadata.self, from: $0) }
        return entries.sorted { $0.capturedAt > $1.capturedAt }
    }
}

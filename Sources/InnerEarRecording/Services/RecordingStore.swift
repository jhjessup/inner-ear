import Foundation
import InnerEarCore

/// Persistence layer for `Recording` objects. All data is stored as JSON
/// files under `~/Library/Application Support/InnerEar/recordings/` (or
/// wherever `InnerEarConfigResolver` resolves to).
///
/// Transcript/Summary persistence lives in `InnerEarTranscription`'s
/// `TranscriptStore` instead — this store has no dependency on that domain
/// at all, by design (see ARCHITECTURE.md).
public final class RecordingStore: Sendable {
    private let disk: JSONDiskStore
    private static let subdirectory = "recordings"

    public init() throws {
        let base = InnerEarConfigResolver.resolveDataDirectory()
        self.disk = try JSONDiskStore(baseDirectory: base, subdirectories: [Self.subdirectory])
    }

    public func save(_ recording: Recording) throws {
        try disk.write(recording, to: disk.fileURL(subdirectory: Self.subdirectory, id: recording.id))
    }

    public func loadRecording(id: UUID) throws -> Recording {
        try disk.read(Recording.self, from: disk.fileURL(subdirectory: Self.subdirectory, id: id), id: id)
    }

    /// All persisted recordings, most recently created first. Skips any
    /// file that fails to decode (e.g. a partially-written or foreign file
    /// in the directory) rather than failing the whole listing.
    public func listRecordings() throws -> [Recording] {
        let files = try disk.listFiles(in: Self.subdirectory)
        let recordings: [Recording] = files.compactMap { disk.decodeOrWarn(Recording.self, from: $0) }
        return recordings.sorted { $0.createdAt > $1.createdAt }
    }

    public func deleteAudioFiles(for recording: Recording) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: recording.microphoneFileURL.path) {
            try fm.removeItem(at: recording.microphoneFileURL)
        }
        if let sysURL = recording.systemAudioFileURL, fm.fileExists(atPath: sysURL.path) {
            try fm.removeItem(at: sysURL)
        }
        // Best-effort: remove the now-possibly-empty containing directory.
        // `try?` because this fails harmlessly if the directory still has
        // other content or doesn't exist — that's fine, not an error case.
        try? fm.removeItem(at: recording.microphoneFileURL.deletingLastPathComponent())
    }

    public func deleteRecordingCatalogEntry(_ id: UUID) throws {
        let url = disk.fileURL(subdirectory: Self.subdirectory, id: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

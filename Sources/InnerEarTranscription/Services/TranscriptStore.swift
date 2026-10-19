import Foundation
import InnerEarCore

/// Persistence layer for `Transcript` and `Summary` objects. All data is
/// stored as JSON files under `~/Library/Application Support/InnerEar/`
/// in `transcripts/` and `summaries/` subdirectories.
///
/// `Recording` persistence lives in `InnerEarRecording`'s `RecordingStore`
/// instead — this store depends on `InnerEarRecording` only indirectly
/// (through model types referencing a `recordingID: UUID`), never on
/// `RecordingStore` itself.
public final class TranscriptStore: Sendable {
    private let disk: JSONDiskStore
    private static let transcriptsSubdirectory = "transcripts"
    private static let summariesSubdirectory = "summaries"

    public init() throws {
        let base = InnerEarConfigResolver.resolveDataDirectory()
        self.disk = try JSONDiskStore(
            baseDirectory: base,
            subdirectories: [Self.transcriptsSubdirectory, Self.summariesSubdirectory]
        )
    }

    // MARK: - Transcript

    public func save(_ transcript: Transcript) throws {
        try disk.write(transcript, to: disk.fileURL(subdirectory: Self.transcriptsSubdirectory, id: transcript.id))
    }

    public func loadTranscript(id: UUID) throws -> Transcript {
        try disk.read(
            Transcript.self,
            from: disk.fileURL(subdirectory: Self.transcriptsSubdirectory, id: id),
            id: id
        )
    }

    /// All persisted transcripts, most recently generated first.
    public func listTranscripts() throws -> [Transcript] {
        let files = try disk.listFiles(in: Self.transcriptsSubdirectory)
        let transcripts: [Transcript] = files.compactMap { disk.decodeOrWarn(Transcript.self, from: $0) }
        return transcripts.sorted { $0.generatedAt > $1.generatedAt }
    }

    public func transcriptFileURL(for transcript: Transcript) -> URL {
        disk.fileURL(subdirectory: Self.transcriptsSubdirectory, id: transcript.id)
    }

    public func deleteTranscript(_ transcript: Transcript) throws {
        let url = transcriptFileURL(for: transcript)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // Best-effort cleanup of the matching summary (linked via
        // transcriptID), if one exists — don't fail the whole delete if
        // this part fails.
        if let summaries = try? listSummaries(),
           let match = summaries.first(where: { $0.transcriptID == transcript.id }) {
            let summaryURL = disk.fileURL(subdirectory: Self.summariesSubdirectory, id: match.id)
            try? FileManager.default.removeItem(at: summaryURL)
        }
    }

    // MARK: - Summary

    public func save(_ summary: Summary) throws {
        try disk.write(summary, to: disk.fileURL(subdirectory: Self.summariesSubdirectory, id: summary.id))
    }

    public func loadSummary(id: UUID) throws -> Summary {
        try disk.read(
            Summary.self,
            from: disk.fileURL(subdirectory: Self.summariesSubdirectory, id: id),
            id: id
        )
    }

    /// All persisted summaries, most recently generated first.
    public func listSummaries() throws -> [Summary] {
        let files = try disk.listFiles(in: Self.summariesSubdirectory)
        let summaries: [Summary] = files.compactMap { disk.decodeOrWarn(Summary.self, from: $0) }
        return summaries.sorted { $0.generatedAt > $1.generatedAt }
    }
}

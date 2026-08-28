import Foundation

/// Errors thrown by RecordingStore when persisting or loading objects.
public enum RecordingStoreError: Error, Equatable, Sendable {
    case notFound(UUID)
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case directoryCreationFailed(path: String)
    case writeFailed(reason: String)
}

/// Concrete persistence layer for Recording, Transcript, and Summary objects.
/// All data is stored as JSON files under ~/Library/Application Support/InnerEar/
/// in dedicated subdirectories: recordings/, transcripts/, summaries/.
public final class RecordingStore: Sendable {
    private let baseDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() throws {
        self.baseDirectory = InnerEarConfigResolver.resolveDataDirectory()

        let subdirs = ["recordings", "transcripts", "summaries"]
        for subdir in subdirs {
            let url = baseDirectory.appendingPathComponent(subdir, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Recording

    public func save(_ recording: Recording) throws {
        let url = baseDirectory
            .appendingPathComponent("recordings", isDirectory: true)
            .appendingPathComponent("\(recording.id.uuidString).json", isDirectory: false)
        try write(recording, to: url)
    }

    public func loadRecording(id: UUID) throws -> Recording {
        let url = baseDirectory
            .appendingPathComponent("recordings", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
        return try read(Recording.self, from: url, id: id)
    }

    /// All persisted recordings, most recently created first. Skips any
    /// file that fails to decode (e.g. a partially-written or foreign file
    /// in the directory) rather than failing the whole listing.
    public func listRecordings() throws -> [Recording] {
        let directory = baseDirectory.appendingPathComponent("recordings", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        let recordings: [Recording] = files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Recording.self, from: data)
        }

        return recordings.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Transcript

    public func save(_ transcript: Transcript) throws {
        let url = baseDirectory
            .appendingPathComponent("transcripts", isDirectory: true)
            .appendingPathComponent("\(transcript.id.uuidString).json", isDirectory: false)
        try write(transcript, to: url)
    }

    public func loadTranscript(id: UUID) throws -> Transcript {
        let url = baseDirectory
            .appendingPathComponent("transcripts", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
        return try read(Transcript.self, from: url, id: id)
    }

    // MARK: - Summary

    public func save(_ summary: Summary) throws {
        let url = baseDirectory
            .appendingPathComponent("summaries", isDirectory: true)
            .appendingPathComponent("\(summary.id.uuidString).json", isDirectory: false)
        try write(summary, to: url)
    }

    public func loadSummary(id: UUID) throws -> Summary {
        let url = baseDirectory
            .appendingPathComponent("summaries", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
        return try read(Summary.self, from: url, id: id)
    }

    // MARK: - Recordings/Transcripts listing & deletion

    public func listTranscripts() throws -> [Transcript] {
        let directory = baseDirectory.appendingPathComponent("transcripts", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Transcript.self, from: data)
        }
    }

    public func listSummaries() throws -> [Summary] {
        let directory = baseDirectory.appendingPathComponent("summaries", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Summary.self, from: data)
        }
    }

    public func transcriptFileURL(for transcript: Transcript) -> URL {
        baseDirectory
            .appendingPathComponent("transcripts", isDirectory: true)
            .appendingPathComponent("\(transcript.id.uuidString).json", isDirectory: false)
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

    public func deleteTranscript(_ transcript: Transcript) throws {
        let url = transcriptFileURL(for: transcript)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // Best-effort cleanup of the matching summary (linked via transcriptID),
        // if one exists — don't fail the whole delete if this part fails.
        if let summaries = try? listSummaries(),
           let match = summaries.first(where: { $0.transcriptID == transcript.id }) {
            let summaryURL = baseDirectory
                .appendingPathComponent("summaries", isDirectory: true)
                .appendingPathComponent("\(match.id.uuidString).json", isDirectory: false)
            try? FileManager.default.removeItem(at: summaryURL)
        }
    }

    public func deleteRecordingCatalogEntry(_ id: UUID) throws {
        let url = baseDirectory
            .appendingPathComponent("recordings", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private Helpers

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch let error as EncodingError {
            throw RecordingStoreError.encodingFailed(reason: error.localizedDescription)
        } catch {
            throw RecordingStoreError.writeFailed(reason: error.localizedDescription)
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL, id: UUID) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecordingStoreError.notFound(id)
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch let error as DecodingError {
            throw RecordingStoreError.decodingFailed(reason: error.localizedDescription)
        } catch {
            throw RecordingStoreError.writeFailed(reason: error.localizedDescription)
        }
    }
}
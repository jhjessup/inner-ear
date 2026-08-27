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
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseDirectory = appSupport.appendingPathComponent("InnerEar", isDirectory: true)

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
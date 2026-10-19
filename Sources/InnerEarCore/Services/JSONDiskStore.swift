import Foundation

/// Errors thrown by a `JSONDiskStore`-backed store when persisting or loading objects.
public enum RecordingStoreError: Error, Equatable, Sendable {
    case notFound(UUID)
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case directoryCreationFailed(path: String)
    case writeFailed(reason: String)
}

/// Shared JSON-file-per-UUID persistence helper. Both `InnerEarRecording`'s
/// `RecordingStore` and `InnerEarTranscription`'s `TranscriptStore` resolve
/// the same base data directory (via `InnerEarConfigResolver`) and persist
/// one pretty-printed, sorted-keys, ISO8601-dated JSON file per object,
/// keyed by UUID — just under different subdirectories. Factored out here
/// (in the shared `InnerEarCore` target, which both already depend on for
/// `InnerEarConfigResolver`) rather than duplicated in both stores.
public struct JSONDiskStore: Sendable {
    public let baseDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates (if needed) every subdirectory this store will write into.
    public init(baseDirectory: URL, subdirectories: [String]) throws {
        self.baseDirectory = baseDirectory
        for subdir in subdirectories {
            let url = baseDirectory.appendingPathComponent(subdir, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func fileURL(subdirectory: String, id: UUID) -> URL {
        baseDirectory
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    public func write<T: Encodable>(_ value: T, to url: URL) throws {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch let error as EncodingError {
            throw RecordingStoreError.encodingFailed(reason: error.localizedDescription)
        } catch {
            throw RecordingStoreError.writeFailed(reason: error.localizedDescription)
        }
    }

    public func read<T: Decodable>(_ type: T.Type, from url: URL, id: UUID) throws -> T {
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

    public func listFiles(in subdirectory: String) throws -> [URL] {
        let directory = baseDirectory.appendingPathComponent(subdirectory, isDirectory: true)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }

    /// Used only by `list*()`-style callers, which intentionally skip
    /// individual files that fail to read/decode rather than failing the
    /// whole listing — a corrupted or partially-written file shouldn't hide
    /// every OTHER object too. Printing a warning here is the difference
    /// between that being silent, undiscoverable data loss and a user
    /// having something concrete (the file path) to report.
    public func decodeOrWarn<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            print("Warning: skipping unreadable \(type) file at \(url.path): \(error)")
            return nil
        }
    }
}

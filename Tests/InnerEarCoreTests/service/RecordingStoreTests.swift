import Foundation
import Testing
import InnerEarCore
@testable import InnerEarRecording

/// Tests for the concrete `RecordingStore` persistence layer — save/load
/// round-trips, list ordering, and deletion of `Recording` catalog entries
/// and audio files.
///
/// Unlike every other `@service` test in this project, this one does NOT
/// use a fake — `RecordingStore` IS the thing under test, and its whole
/// job is real filesystem I/O, so faking it would test nothing. It's kept
/// hermetic instead: `RecordingStore.init()` resolves its base directory
/// via `InnerEarConfigResolver.resolveDataDirectory()` called with no
/// arguments, which reads the REAL `ProcessInfo.processInfo.environment`
/// (unlike `InnerEarConfigResolverTests`, which can inject a fake
/// dictionary because it calls the resolver directly). To point
/// `RecordingStore` at a throwaway temp directory instead of the real
/// `~/Library/Application Support/InnerEar/`, this file sets the real
/// process's `INNEREAR_DATA_DIR` env var via `setenv` — the same
/// documented override mechanism `InnerEarConfigResolver` supports for
/// exactly this purpose (see its doc comment).
///
/// Nested under `DataDirectoryTests` (not a bare top-level `@Suite`) — see
/// that type's doc comment for why: `.serialized` alone on this suite
/// isn't enough, since it doesn't serialize against the OTHER suites
/// (`TranscriptStoreTests`, `RecordingDeletionIntegrationTests`) that also
/// mutate the same process-wide env var.
extension DataDirectoryTests {

@Suite(.serialized)
struct RecordingStoreTests {

    // MARK: - Fixtures

    /// Points `INNEREAR_DATA_DIR` at a fresh, uniquely-named temp directory
    /// and returns a `RecordingStore` resolved against it. Called at the
    /// start of every test (not once for the whole suite) so each test gets
    /// its own isolated directory — cheap, and removes any possibility of
    /// one test's leftover files being visible to another even with
    /// serialized execution.
    private func makeStore() throws -> RecordingStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("innerear-store-tests-\(UUID().uuidString)", isDirectory: true)
        setenv("INNEREAR_DATA_DIR", tempDir.path, 1)
        return try RecordingStore()
    }

    private func makeRecording(
        title: String = "Test Recording",
        createdAt: Date = Date(timeIntervalSince1970: 1_000_000),
        hasSystemAudio: Bool = false
    ) -> Recording {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("innerear-store-tests-audio-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let micURL = dir.appendingPathComponent("mic.caf")
        FileManager.default.createFile(atPath: micURL.path, contents: Data())
        var systemURL: URL?
        if hasSystemAudio {
            let sysURL = dir.appendingPathComponent("system.caf")
            FileManager.default.createFile(atPath: sysURL.path, contents: Data())
            systemURL = sysURL
        }
        return Recording(
            title: title,
            createdAt: createdAt,
            duration: 60,
            microphoneFileURL: micURL,
            systemAudioFileURL: systemURL
        )
    }

    // MARK: - Save/load round-trip

    @Test
    func saveRecording_thenLoadByID_returnsEquivalentRecording() throws {
        let store = try makeStore()
        let recording = makeRecording()

        try store.save(recording)
        let loaded = try store.loadRecording(id: recording.id)

        #expect(loaded == recording)
    }

    @Test
    func loadRecording_whenNotFound_throwsNotFound() throws {
        let store = try makeStore()
        let missingID = UUID()

        #expect(throws: RecordingStoreError.notFound(missingID)) {
            try store.loadRecording(id: missingID)
        }
    }

    @Test
    func listRecordings_returnsMostRecentlyCreatedFirst() throws {
        let store = try makeStore()
        let older = makeRecording(title: "Older", createdAt: Date(timeIntervalSince1970: 1_000_000))
        let newer = makeRecording(title: "Newer", createdAt: Date(timeIntervalSince1970: 2_000_000))

        // Save older first — the ordering must come from `createdAt`, not
        // save order or filesystem enumeration order.
        try store.save(older)
        try store.save(newer)

        let listed = try store.listRecordings()

        #expect(listed.map(\.id) == [newer.id, older.id])
    }

    @Test
    func listRecordings_skipsCorruptFile_ratherThanFailingWholeListing() throws {
        let store = try makeStore()
        let good = makeRecording(title: "Good")
        try store.save(good)

        // Write a corrupt/foreign file directly into the recordings/
        // directory to simulate a partially-written or foreign file —
        // documented existing behavior: listRecordings() skips files that
        // fail to decode rather than failing the whole listing. Re-derive
        // the store's directory via the env var makeStore() just set.
        let dataDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["INNEREAR_DATA_DIR"]!)
        let corruptURL = dataDir.appendingPathComponent("recordings").appendingPathComponent("\(UUID().uuidString).json")
        try "not valid json".write(to: corruptURL, atomically: true, encoding: .utf8)

        let listed = try store.listRecordings()

        #expect(listed.map(\.id) == [good.id])
    }

    // MARK: - Deletion

    @Test
    func deleteAudioFiles_removesMicAndSystemAudioFiles_andContainingDirectory() throws {
        let store = try makeStore()
        let recording = makeRecording(hasSystemAudio: true)
        let micURL = recording.microphoneFileURL
        let sysURL = recording.systemAudioFileURL!
        let containingDir = micURL.deletingLastPathComponent()

        #expect(FileManager.default.fileExists(atPath: micURL.path))
        #expect(FileManager.default.fileExists(atPath: sysURL.path))

        try store.deleteAudioFiles(for: recording)

        #expect(!FileManager.default.fileExists(atPath: micURL.path))
        #expect(!FileManager.default.fileExists(atPath: sysURL.path))
        // Best-effort cleanup of the now-empty containing directory — no
        // orphaned empty directory left behind either.
        #expect(!FileManager.default.fileExists(atPath: containingDir.path))
    }

    @Test
    func deleteRecordingCatalogEntry_removesRecordingMetadataFile() throws {
        let store = try makeStore()
        let recording = makeRecording()
        try store.save(recording)

        try store.deleteRecordingCatalogEntry(recording.id)

        #expect(throws: RecordingStoreError.notFound(recording.id)) {
            try store.loadRecording(id: recording.id)
        }
    }
}

}

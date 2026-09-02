import Foundation
import Testing
@testable import InnerEarCore

/// Tests for the concrete `RecordingStore` persistence layer — save/load
/// round-trips, list ordering, and deletion (including MTM-6: "deleting a
/// recording removes both its audio file and its persisted metadata/
/// transcript — no orphaned files remain on disk").
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
/// `@Suite(.serialized)`: Swift Testing runs a suite's tests concurrently
/// by default. Since every test in this file shares one process-wide env
/// var (and therefore one temp directory), concurrent execution would be
/// a real data race — one test's `setenv` could change the directory out
/// from under another test mid-run. Forcing serial execution avoids that;
/// it's cheap here since these tests are small, fast, real-filesystem
/// tests, not the kind of large parallel suite serialization would slow
/// down noticeably.
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

    private func makeTranscript(
        recordingID: UUID = UUID(),
        generatedAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> Transcript {
        let speaker = TestFixtures.speaker()
        return Transcript(
            recordingID: recordingID,
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [speaker],
            segments: [
                TranscriptSegment(speakerID: speaker.id, text: "Hello world", startTime: 0, endTime: 1)
            ],
            generatedAt: generatedAt,
            recordingStartedAt: generatedAt
        )
    }

    private func makeSummary(transcriptID: UUID, generatedAt: Date = Date(timeIntervalSince1970: 1_000_000)) -> Summary {
        Summary(
            transcriptID: transcriptID,
            overview: "A short meeting.",
            keyPoints: ["Point one"],
            decisions: [],
            actionItems: [],
            generatedByModel: "extractive-v1",
            generatedAt: generatedAt
        )
    }

    // MARK: - Recording save/load round-trip

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

    // MARK: - Transcript save/load round-trip

    @Test
    func saveTranscript_thenLoadByID_returnsEquivalentTranscript() throws {
        let store = try makeStore()
        let transcript = makeTranscript()

        try store.save(transcript)
        let loaded = try store.loadTranscript(id: transcript.id)

        #expect(loaded == transcript)
    }

    @Test
    func listTranscripts_returnsMostRecentlyGeneratedFirst() throws {
        let store = try makeStore()
        let older = makeTranscript(generatedAt: Date(timeIntervalSince1970: 1_000_000))
        let newer = makeTranscript(generatedAt: Date(timeIntervalSince1970: 2_000_000))

        try store.save(older)
        try store.save(newer)

        let listed = try store.listTranscripts()

        #expect(listed.map(\.id) == [newer.id, older.id])
    }

    // MARK: - Summary save/load round-trip

    @Test
    func saveSummary_thenLoadByID_returnsEquivalentSummary() throws {
        let store = try makeStore()
        let summary = makeSummary(transcriptID: UUID())

        try store.save(summary)
        let loaded = try store.loadSummary(id: summary.id)

        #expect(loaded == summary)
    }

    @Test
    func listSummaries_returnsMostRecentlyGeneratedFirst() throws {
        let store = try makeStore()
        let older = makeSummary(transcriptID: UUID(), generatedAt: Date(timeIntervalSince1970: 1_000_000))
        let newer = makeSummary(transcriptID: UUID(), generatedAt: Date(timeIntervalSince1970: 2_000_000))

        try store.save(older)
        try store.save(newer)

        let listed = try store.listSummaries()

        #expect(listed.map(\.id) == [newer.id, older.id])
    }

    // MARK: - transcriptFileURL

    @Test
    func transcriptFileURL_matchesWhereSaveActuallyWrites() throws {
        let store = try makeStore()
        let transcript = makeTranscript()
        try store.save(transcript)

        let url = store.transcriptFileURL(for: transcript)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Deletion (MTM-6: no orphaned files after delete)

    /// Satisfies TEST_DOCTRINE.md MTM-6: "Deleting a recording removes both
    /// its audio file and its persisted metadata/transcript — no orphaned
    /// files remain on disk."
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
    func deleteTranscript_removesTranscriptFile_andLinkedSummary_noOrphans() throws {
        let store = try makeStore()
        let transcript = makeTranscript()
        let summary = makeSummary(transcriptID: transcript.id)
        try store.save(transcript)
        try store.save(summary)

        let transcriptURL = store.transcriptFileURL(for: transcript)
        #expect(FileManager.default.fileExists(atPath: transcriptURL.path))

        try store.deleteTranscript(transcript)

        #expect(!FileManager.default.fileExists(atPath: transcriptURL.path))
        // The linked summary (matched via transcriptID) must be gone too —
        // otherwise it's an orphan pointing at a transcript that no longer
        // exists.
        #expect(throws: RecordingStoreError.notFound(summary.id)) {
            try store.loadSummary(id: summary.id)
        }
    }

    @Test
    func deleteTranscript_doesNotDeleteUnrelatedSummary() throws {
        let store = try makeStore()
        let transcript = makeTranscript()
        let unrelatedSummary = makeSummary(transcriptID: UUID()) // different transcriptID
        try store.save(transcript)
        try store.save(unrelatedSummary)

        try store.deleteTranscript(transcript)

        // A summary NOT linked to the deleted transcript must survive.
        let loaded = try store.loadSummary(id: unrelatedSummary.id)
        #expect(loaded == unrelatedSummary)
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

    @Test
    func fullDeleteFlow_recordingAudioTranscriptSummary_leavesNoOrphans() throws {
        // End-to-end version of MTM-6: delete every artifact belonging to
        // one recording (catalog entry, audio files, transcript, and its
        // linked summary) and confirm nothing is left on disk anywhere.
        let store = try makeStore()
        let recording = makeRecording(hasSystemAudio: true)
        let transcript = makeTranscript(recordingID: recording.id)
        let summary = makeSummary(transcriptID: transcript.id)
        try store.save(recording)
        try store.save(transcript)
        try store.save(summary)

        try store.deleteAudioFiles(for: recording)
        try store.deleteTranscript(transcript)
        try store.deleteRecordingCatalogEntry(recording.id)

        #expect(!FileManager.default.fileExists(atPath: recording.microphoneFileURL.path))
        #expect(!FileManager.default.fileExists(atPath: recording.systemAudioFileURL!.path))
        #expect(try store.listRecordings().isEmpty)
        #expect(try store.listTranscripts().isEmpty)
        #expect(try store.listSummaries().isEmpty)
    }
}

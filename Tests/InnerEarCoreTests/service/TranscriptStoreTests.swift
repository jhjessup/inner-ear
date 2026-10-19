import Foundation
import Testing
import InnerEarCore
@testable import InnerEarTranscription

/// Tests for the concrete `TranscriptStore` persistence layer — save/load
/// round-trips, list ordering, and transcript+linked-summary deletion. See
/// `RecordingStoreTests` for the `Recording`-side equivalent and
/// `RecordingDeletionIntegrationTests` for the cross-store MTM-6 flow.
///
/// Same hermetic-via-`INNEREAR_DATA_DIR`-env-var rationale as
/// `RecordingStoreTests`, and nested under `DataDirectoryTests` for the
/// same reason — see that type's doc comment.
extension DataDirectoryTests {

@Suite(.serialized)
struct TranscriptStoreTests {

    // MARK: - Fixtures

    private func makeStore() throws -> TranscriptStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("innerear-transcript-store-tests-\(UUID().uuidString)", isDirectory: true)
        setenv("INNEREAR_DATA_DIR", tempDir.path, 1)
        return try TranscriptStore()
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

    // MARK: - Deletion

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
}

}

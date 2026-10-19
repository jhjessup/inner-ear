import Foundation
import Testing
import InnerEarCore
@testable import InnerEarRecording
@testable import InnerEarTranscription

/// Satisfies TEST_DOCTRINE.md MTM-6: "Deleting a recording removes both its
/// audio file and its persisted metadata/transcript — no orphaned files
/// remain on disk." Exercises `RecordingStore` and `TranscriptStore`
/// together, pointed at the same data directory, since that's how
/// `TUIRunLoop` actually drives a delete in practice — see
/// `RecordingStoreTests`/`TranscriptStoreTests` for the narrower per-store
/// tests. Nested under `DataDirectoryTests` — see that type's doc comment
/// for why (shared process-wide `INNEREAR_DATA_DIR` env var).
extension DataDirectoryTests {

@Suite(.serialized)
struct RecordingDeletionIntegrationTests {

    private func makeStores() throws -> (recording: RecordingStore, transcript: TranscriptStore) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("innerear-deletion-integration-tests-\(UUID().uuidString)", isDirectory: true)
        setenv("INNEREAR_DATA_DIR", tempDir.path, 1)
        return (try RecordingStore(), try TranscriptStore())
    }

    private func makeRecording(hasSystemAudio: Bool) -> Recording {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("innerear-deletion-integration-audio-\(UUID().uuidString)", isDirectory: true)
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
            title: "Test Recording",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            duration: 60,
            microphoneFileURL: micURL,
            systemAudioFileURL: systemURL
        )
    }

    @Test
    func fullDeleteFlow_recordingAudioTranscriptSummary_leavesNoOrphans() throws {
        let (recordingStore, transcriptStore) = try makeStores()
        let recording = makeRecording(hasSystemAudio: true)
        let speaker = TestFixtures.speaker()
        let transcript = Transcript(
            recordingID: recording.id,
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [speaker],
            segments: [TranscriptSegment(speakerID: speaker.id, text: "Hello world", startTime: 0, endTime: 1)],
            generatedAt: Date(timeIntervalSince1970: 1_000_000),
            recordingStartedAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let summary = Summary(
            transcriptID: transcript.id,
            overview: "A short meeting.",
            keyPoints: ["Point one"],
            decisions: [],
            actionItems: [],
            generatedByModel: "extractive-v1",
            generatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try recordingStore.save(recording)
        try transcriptStore.save(transcript)
        try transcriptStore.save(summary)

        try recordingStore.deleteAudioFiles(for: recording)
        try transcriptStore.deleteTranscript(transcript)
        try recordingStore.deleteRecordingCatalogEntry(recording.id)

        #expect(!FileManager.default.fileExists(atPath: recording.microphoneFileURL.path))
        #expect(!FileManager.default.fileExists(atPath: recording.systemAudioFileURL!.path))
        #expect(try recordingStore.listRecordings().isEmpty)
        #expect(try transcriptStore.listTranscripts().isEmpty)
        #expect(try transcriptStore.listSummaries().isEmpty)
    }
}

}

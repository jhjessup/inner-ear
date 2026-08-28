import Foundation
import Testing
@testable import InnerEarTUIKit
import InnerEarCore

/// Tests for the pure `TUIRenderer.render` function.
///
/// All tests assert on the exact string content of the returned line array.
/// No I/O, no terminal interaction — pure function testing.
struct TUIRendererTests {

    // MARK: - Fixtures

    private func makeRecording(title: String = "Test Recording") -> Recording {
        Recording(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: title,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            duration: 60,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/test.caf")
        )
    }

    private func makeTranscript() -> Transcript {
        let speaker = Speaker(label: "Speaker 1", colorHex: "#3478F6", isLocalUser: true)
        return Transcript(
            id: UUID(),
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [speaker],
            segments: [
                TranscriptSegment(speakerID: speaker.id, text: "Hello world, this is a test transcript.", startTime: 0, endTime: 2)
            ],
            generatedAt: Date()
        )
    }

    private func makeSummary() -> Summary {
        Summary(
            id: UUID(),
            transcriptID: UUID(),
            overview: "This is the overview.",
            keyPoints: ["Key point one", "Key point two"],
            decisions: ["Decision one"],
            actionItems: [Summary.ActionItem(text: "Action item one", ownerSpeakerID: nil)],
            generatedByModel: "extractive-v1",
            generatedAt: Date()
        )
    }

    // MARK: - Main Menu Tests

    @Test
    func mainMenu_containsExpectedLines() {
        let lines = TUIRenderer.render(state: .mainMenu, width: 80, height: 24)
        #expect(lines.contains { $0.contains("InnerEar") })
        #expect(lines.contains { $0.contains("[1] Record") })
        #expect(lines.contains { $0.contains("[2] Browse Recordings") })
        #expect(lines.contains { $0.contains("[q] Quit") })
    }

    // MARK: - Recording State Tests

    @Test
    func recording_showsRecordingIndicator_andStopHint() {
        // Use a fixed startedAt so elapsed is deterministic-ish (but we can't
        // control Date() inside render, so just check for the static parts).
        let startedAt = Date(timeIntervalSince1970: 0)
        let lines = TUIRenderer.render(state: .recording(startedAt: startedAt, captureSystemAudio: true), width: 80, height: 24)
        #expect(lines.count == 1)
        #expect(lines[0].contains("Recording..."))
        #expect(lines[0].contains("[s] Stop"))
        #expect(lines[0].contains("system audio: on"))
    }

    @Test
    func recording_withoutSystemAudio_showsOff() {
        let startedAt = Date(timeIntervalSince1970: 0)
        let lines = TUIRenderer.render(state: .recording(startedAt: startedAt, captureSystemAudio: false), width: 80, height: 24)
        #expect(lines[0].contains("system audio: off"))
    }

    // MARK: - Browsing Tests

    @Test
    func browsing_withTwoRecordings_showsBothTitles_selectedHasPrefix() {
        let rec1 = makeRecording(title: "First Meeting")
        let rec2 = Recording(
            id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
            title: "Second Meeting",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            duration: 120,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/test2.caf")
        )
        let recordings = [rec1, rec2]

        // Selected index 0 -> first recording should have "> " prefix
        let lines0 = TUIRenderer.render(state: .browsing(recordings: recordings, selectedIndex: 0), width: 80, height: 24)
        #expect(lines0.contains { $0.contains("> First Meeting") })
        #expect(lines0.contains { $0.contains("  Second Meeting") })

        // Selected index 1 -> second recording should have "> " prefix
        let lines1 = TUIRenderer.render(state: .browsing(recordings: recordings, selectedIndex: 1), width: 80, height: 24)
        #expect(lines1.contains { $0.contains("  First Meeting") })
        #expect(lines1.contains { $0.contains("> Second Meeting") })

        // Footer should be present
        #expect(lines0.contains { $0.contains("[j/k] Move") })
        #expect(lines1.contains { $0.contains("[Enter] Select") })
        #expect(lines0.contains { $0.contains("[b] Back") })
    }

    @Test
    func browsing_empty_showsEmptyMessage() {
        let lines = TUIRenderer.render(state: .browsing(recordings: [], selectedIndex: 0), width: 80, height: 24)
        #expect(lines.contains { $0.contains("No recordings yet") })
        #expect(lines.contains { $0.contains("[b] Back") })
    }

    // MARK: - Viewing Results Tests

    @Test
    func viewingResults_showsTranscriptText() {
        let transcript = makeTranscript()
        let lines = TUIRenderer.render(state: .viewingResults(transcript: transcript, summary: nil, scrollOffset: 0), width: 80, height: 24)
        #expect(lines.contains { $0.contains("Hello world, this is a test transcript") })
    }

    @Test
    func viewingResults_withSummary_showsSummarySections() {
        let transcript = makeTranscript()
        let summary = makeSummary()
        let lines = TUIRenderer.render(state: .viewingResults(transcript: transcript, summary: summary, scrollOffset: 0), width: 80, height: 24)
        #expect(lines.contains { $0.contains("--- Summary ---") })
        #expect(lines.contains { $0.contains("This is the overview") })
        #expect(lines.contains { $0.contains("Key Points:") })
        #expect(lines.contains { $0.contains("- Key point one") })
        #expect(lines.contains { $0.contains("Decisions:") })
        #expect(lines.contains { $0.contains("- Decision one") })
        #expect(lines.contains { $0.contains("Action Items:") })
        #expect(lines.contains { $0.contains("- Action item one") })
    }

    // MARK: - Error Message Tests

    @Test
    func errorMessage_showsMessage_andBackHint() {
        let lines = TUIRenderer.render(state: .errorMessage("Disk full"), width: 80, height: 24)
        #expect(lines.contains { $0.contains("Error: Disk full") })
        #expect(lines.contains { $0.contains("[b] Back") })
    }

    // MARK: - Height Clamping Tests

    @Test
    func render_neverExceedsHeight() {
        // Create 50 recordings, render with height=10
        var recordings: [Recording] = []
        for i in 0..<50 {
            recordings.append(Recording(
                id: UUID(),
                title: "Recording \(i)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(i * 1000)),
                duration: 60,
                microphoneFileURL: URL(fileURLWithPath: "/tmp/test\(i).caf")
            ))
        }
        let lines = TUIRenderer.render(state: .browsing(recordings: recordings, selectedIndex: 25), width: 80, height: 10)
        #expect(lines.count <= 10)
    }

    @Test
    func viewingResults_longContent_respectsHeight() {
        let speaker = Speaker(label: "Speaker 1", colorHex: "#3478F6", isLocalUser: true)
        // Create a transcript with very long text that will wrap to many lines
        let longText = String(repeating: "This is a very long sentence that will wrap across multiple lines when rendered at a narrow width. ", count: 20)
        let transcript = Transcript(
            id: UUID(),
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [speaker],
            segments: [
                TranscriptSegment(speakerID: speaker.id, text: longText, startTime: 0, endTime: 100)
            ],
            generatedAt: Date()
        )
        let lines = TUIRenderer.render(state: .viewingResults(transcript: transcript, summary: nil, scrollOffset: 0), width: 40, height: 10)
        #expect(lines.count <= 10)
    }

    // MARK: - Truncation Tests

    @Test
    func longLines_areTruncatedWithEllipsis() {
        let longTitle = String(repeating: "A", count: 100)
        let recording = Recording(
            id: UUID(),
            title: longTitle,
            createdAt: Date(),
            duration: 60,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/test.caf")
        )
        let lines = TUIRenderer.render(state: .recordingSaved(recording), width: 40, height: 24)
        // The recording saved line should be truncated
        #expect(lines[0].hasSuffix("…") || lines[0].count <= 40)
    }
}
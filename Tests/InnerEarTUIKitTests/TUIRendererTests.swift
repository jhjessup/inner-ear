import Foundation
import Testing
@testable import InnerEarTUIKit
import InnerEarCore

/// Tests for the pure `TUIRenderer.render` function.
///
/// All tests assert on the string content of the returned line array.
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

    // MARK: - Minimum size guard

    @Test
    func render_belowMinWidth_returnsSingleLine() {
        let state = TUIState()
        let lines = TUIRenderer.render(state: state, width: TUIRenderer.minWidth - 1, height: 24)
        #expect(lines.count == 1)
        #expect(lines[0].contains("Terminal too small"))
    }

    @Test
    func render_belowMinHeight_returnsSingleLine() {
        let state = TUIState()
        let lines = TUIRenderer.render(state: state, width: 80, height: TUIRenderer.minHeight - 1)
        #expect(lines.count == 1)
        #expect(lines[0].contains("Terminal too small"))
    }

    // MARK: - Line count bound

    @Test
    func render_neverExceedsHeight() {
        let state = TUIState()
        let height = 20
        let lines = TUIRenderer.render(state: state, width: 80, height: height)
        #expect(lines.count <= height)
    }

    @Test
    func render_neverExceedsHeight_atVariousSizes() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [], selectedIndex: 0)
        )
        for h in [18, 22, 30, 50] {
            let lines = TUIRenderer.render(state: state, width: 80, height: h)
            #expect(lines.count <= h)
        }
    }

    // MARK: - Nav pane / title / border

    @Test
    func render_containsAllSectionNames() {
        let state = TUIState()
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Record"))
        #expect(joined.contains("Recordings"))
        #expect(joined.contains("Settings"))
    }

    @Test
    func render_selectedSectionHasMarker() {
        let state = TUIState(selectedSection: 1) // Recordings
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains(">"))
    }

    @Test
    func render_includesInnerEarTitle() {
        let state = TUIState()
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("InnerEar"))
    }

    @Test
    func render_usesBoxDrawingChars() {
        let state = TUIState()
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("┌"))
        #expect(joined.contains("┐"))
        #expect(joined.contains("└"))
        #expect(joined.contains("┘"))
        #expect(joined.contains("│"))
        #expect(joined.contains("─"))
    }

    // MARK: - Footer legend changes between states

    @Test
    func render_footerDiffersBetweenNavFocused_andSettingsEditing() {
        let navFocused = TUIState(focusedPane: .navigation, selectedSection: 0)
        let settingsEditing = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .editing(currentInput: "/data")
        )
        let navFooter = TUIRenderer.footerText(for: navFocused)
        let editingFooter = TUIRenderer.footerText(for: settingsEditing)
        #expect(navFooter != editingFooter)
        #expect(navFooter.contains("Select"))
        #expect(editingFooter.contains("Save"))
    }

    @Test
    func render_footerDiffersBetweenRecording_andViewing() {
        let recording = TUIState(
            focusedPane: .detail,
            selectedSection: 0,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let viewing = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 0)
        )
        let recFooter = TUIRenderer.footerText(for: recording)
        let viewFooter = TUIRenderer.footerText(for: viewing)
        #expect(recFooter != viewFooter)
        #expect(recFooter.contains("Stop"))
        #expect(viewFooter.contains("Scroll"))
    }

    // MARK: - Modal overlay

    @Test
    func render_modalContainsMessage() {
        let state = TUIState(modal: .error("disk full boom"))
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("boom"))
        #expect(joined.contains("[Enter/Esc] Dismiss"))
    }

    // MARK: - Per-section rendering

    @Test
    func record_idle_rendersStartHint() {
        let state = TUIState(focusedPane: .detail, selectedSection: 0, record: .idle)
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Press Enter"))
    }

    @Test
    func record_prompting_rendersSystemAudioPrompt() {
        let state = TUIState(focusedPane: .detail, selectedSection: 0, record: .prompting)
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("system audio") || joined.contains("Include system audio"))
    }

    @Test
    func record_recording_rendersTimerAndStopHint() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 0,
            record: .recording(startedAt: Date(timeIntervalSince1970: 0), captureSystemAudio: true)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Recording"))
        #expect(joined.contains("[s] Stop"))
        #expect(joined.contains("system audio: on"))
    }

    @Test
    func record_recording_withoutSystemAudio_showsOff() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 0,
            record: .recording(startedAt: Date(timeIntervalSince1970: 0), captureSystemAudio: false)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("system audio: off"))
    }

    @Test
    func record_saved_rendersIdAndEnterHint() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 0,
            record: .saved(makeRecording())
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("11111111-2222-3333-4444-555555555555"))
        #expect(joined.contains("Process now"))
    }

    // MARK: - Recordings section

    @Test
    func recordings_list_empty_rendersEmptyMessage() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [], selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("No recordings yet"))
    }

    @Test
    func recordings_list_nonEmpty_rendersTitlesAndSelectionMarker() {
        let recs = [
            makeRecording(title: "First"),
            Recording(
                id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
                title: "Second",
                createdAt: Date(timeIntervalSince1970: 2_000_000),
                duration: 120,
                microphoneFileURL: URL(fileURLWithPath: "/tmp/test2.caf")
            )
        ]
        let entries = recs.map { rec in
            RecordingListEntry(
                recording: rec,
                hasAudio: true,
                transcript: nil,
                summary: nil,
                transcriptFileURL: nil
            )
        }
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: entries, selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("First"))
        #expect(joined.contains("Second"))
        #expect(joined.contains(">"))
    }

    @Test
    func recordings_processing_rendersStatusLine() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .processing(recording: makeRecording(title: "Demo"), statusLine: "Diarizing...")
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Demo"))
        #expect(joined.contains("Diarizing"))
    }

    @Test
    func recordings_viewingResults_rendersTranscript() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 0)
        )
        // Use a wide terminal so the detail pane (width - navPaneWidth - 3)
        // has room for the full "[MM:SS] Speaker: text" line without
        // hitting the word-wrap's non-word-boundary-aware line break —
        // at width 80 the ~55-char detail pane wraps this line mid-word,
        // which is a real (documented, v1-accepted) renderer limitation,
        // not something this test is trying to exercise.
        let lines = TUIRenderer.render(state: state, width: 120, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Hello world, this is a test transcript"))
    }

    @Test
    func recordings_viewingResults_rendersPerSegmentTimestampAndSpeaker_notFlatEcho() {
        // "Rendered, not echoed": each segment must show its own MM:SS
        // timestamp and speaker label, not just a flat concatenated blob.
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        // makeTranscript()'s single segment starts at time 0 with speaker "Speaker 1".
        #expect(joined.contains("[00:00] Speaker 1:"))
    }

    @Test
    func recordings_list_marker_reflectsAudioAndTranscriptPresence() {
        let withBoth = RecordingListEntry(
            recording: makeRecording(title: "Both"),
            hasAudio: true,
            transcript: makeTranscript(),
            summary: nil,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
        )
        let audioOnly = RecordingListEntry(
            recording: Recording(
                id: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!,
                title: "AudioOnly",
                createdAt: Date(timeIntervalSince1970: 1_000_000),
                duration: 10,
                microphoneFileURL: URL(fileURLWithPath: "/tmp/audioonly.caf")
            ),
            hasAudio: true,
            transcript: nil,
            summary: nil,
            transcriptFileURL: nil
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [withBoth, audioOnly], selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("[AT] Both"))
        #expect(joined.contains("[A-] AudioOnly"))
    }

    @Test
    func recordings_list_attributeBar_showsCaptureTimeAndFilePaths() {
        let recording = Recording(
            id: UUID(),
            title: "With Paths",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 30,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/mic-audio.caf")
        )
        let transcript = makeTranscript()
        let entry = RecordingListEntry(
            recording: recording,
            hasAudio: true,
            transcript: transcript,
            summary: nil,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/transcript-file.json")
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [entry], selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Captured:"))
        #expect(joined.contains("/tmp/mic-audio.caf"))
        #expect(joined.contains("/tmp/transcript-file.json"))
    }

    @Test
    func recordings_list_attributeBar_showsPlaceholdersWhenMissing() {
        let entry = RecordingListEntry(
            recording: Recording(
                id: UUID(),
                title: "Nothing",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                duration: 5,
                microphoneFileURL: URL(fileURLWithPath: "/tmp/gone.caf")
            ),
            hasAudio: false,
            transcript: nil,
            summary: nil,
            transcriptFileURL: nil
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [entry], selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("not present"))
        #expect(joined.contains("not yet generated"))
    }

    @Test
    func recordings_confirmGenerateTranscript_rendersPromptWithTitle() {
        let entries = [
            RecordingListEntry(
                recording: makeRecording(title: "Needs Transcript"),
                hasAudio: true,
                transcript: nil,
                summary: nil,
                transcriptFileURL: nil
            )
        ]
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmGenerateTranscript(entries: entries, selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Needs Transcript"))
        #expect(joined.contains("[y/n]"))
    }

    @Test
    func recordings_confirmDelete_rendersPromptWithTitleAndOptions() {
        let entries = [
            RecordingListEntry(
                recording: makeRecording(title: "Doomed"),
                hasAudio: true,
                transcript: makeTranscript(),
                summary: nil,
                transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
            )
        ]
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmDelete(entries: entries, selectedIndex: 0)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("Doomed"))
        #expect(joined.contains("[a] Audio only"))
        #expect(joined.contains("[t] Transcript only"))
        #expect(joined.contains("[b] Both"))
    }

    @Test
    func footer_differsAcrossListConfirmGenerateAndConfirmDeleteStates() {
        let entries = [
            RecordingListEntry(
                recording: makeRecording(),
                hasAudio: true,
                transcript: nil,
                summary: nil,
                transcriptFileURL: nil
            )
        ]
        let listFooter = TUIRenderer.footerText(for: TUIState(
            focusedPane: .detail, selectedSection: 1,
            recordings: .list(entries: entries, selectedIndex: 0)
        ))
        let generateFooter = TUIRenderer.footerText(for: TUIState(
            focusedPane: .detail, selectedSection: 1,
            recordings: .confirmGenerateTranscript(entries: entries, selectedIndex: 0)
        ))
        let deleteFooter = TUIRenderer.footerText(for: TUIState(
            focusedPane: .detail, selectedSection: 1,
            recordings: .confirmDelete(entries: entries, selectedIndex: 0)
        ))
        #expect(listFooter.contains("[d] Delete"))
        #expect(generateFooter.contains("Generate"))
        #expect(deleteFooter.contains("Audio"))
        #expect(listFooter != generateFooter)
        #expect(generateFooter != deleteFooter)
    }

    // MARK: - Settings section

    @Test
    func settings_viewing_rendersResolvedPath() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .viewing(resolvedPath: "/data/inner", source: .configFile)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("/data/inner"))
        #expect(joined.contains("config.json"))
        #expect(joined.contains("[e] Edit"))
    }

    @Test
    func settings_viewing_envVarSource_rendersEnvVarDescription() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .viewing(resolvedPath: "/from/env", source: .envVar)
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("INNEREAR_DATA_DIR"))
    }

    @Test
    func settings_editing_rendersCurrentInput() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .editing(currentInput: "/typed/path")
        )
        let lines = TUIRenderer.render(state: state, width: 80, height: 24)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("/typed/path"))
    }
}

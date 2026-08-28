import Foundation
import Testing
@testable import InnerEarTUIKit
import InnerEarCore

/// Tests for the pure `TUIController.reduce` state machine.
///
/// Uses Swift Testing (`@Test` / `#expect`) per the project's test doctrine.
/// All tests construct explicit state/event pairs and assert on the returned
/// `(nextState, effects)` tuple — no async, no I/O, no real services.
struct TUIControllerTests {

    // MARK: - Fixtures

    private func makeRecording(title: String = "Test Recording") -> Recording {
        Recording(
            id: UUID(),
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
                TranscriptSegment(speakerID: speaker.id, text: "Hello world", startTime: 0, endTime: 1)
            ],
            generatedAt: Date()
        )
    }

    private func makeSummary() -> Summary {
        Summary(
            id: UUID(),
            transcriptID: UUID(),
            overview: "Test overview",
            keyPoints: ["Point 1", "Point 2"],
            decisions: ["Decision 1"],
            actionItems: [Summary.ActionItem(text: "Action 1", ownerSpeakerID: nil)],
            generatedByModel: "extractive-v1",
            generatedAt: Date()
        )
    }

    // MARK: - Main Menu Tests

    @Test
    func mainMenu_key1_transitionsToRecordPrompt() {
        let (nextState, effects) = TUIController.reduce(.mainMenu, .key("1"))
        #expect(nextState == .recordPrompt)
        #expect(effects.isEmpty)
    }

    @Test
    func mainMenu_keyQ_emitsQuitEffect() {
        let (nextState, effects) = TUIController.reduce(.mainMenu, .key("q"))
        #expect(nextState == .mainMenu)
        #expect(effects == [.quit])
    }

    @Test
    func mainMenu_key2_emitsLoadRecordingsEffect_staysOnMainMenu() {
        let (nextState, effects) = TUIController.reduce(.mainMenu, .key("2"))
        #expect(nextState == .mainMenu)
        #expect(effects == [.loadRecordings])
    }

    // MARK: - Record Prompt Tests

    @Test
    func recordPrompt_keyY_transitionsToRecording_withStartRecordingTrueEffect() {
        let (nextState, effects) = TUIController.reduce(.recordPrompt, .key("y"))
        if case .recording(_, let captureSystemAudio) = nextState {
            #expect(captureSystemAudio == true)
        } else {
            #expect(Bool(false), "Expected .recording state")
        }
        #expect(effects == [.startRecording(captureSystemAudio: true)])
    }

    @Test
    func recordPrompt_keyN_transitionsToRecording_withStartRecordingFalseEffect() {
        let (nextState, effects) = TUIController.reduce(.recordPrompt, .key("n"))
        if case .recording(_, let captureSystemAudio) = nextState {
            #expect(captureSystemAudio == false)
        } else {
            #expect(Bool(false), "Expected .recording state")
        }
        #expect(effects == [.startRecording(captureSystemAudio: false)])
    }

    @Test
    func recordPrompt_keyB_returnsToMainMenu() {
        let (nextState, effects) = TUIController.reduce(.recordPrompt, .key("b"))
        #expect(nextState == .mainMenu)
        #expect(effects.isEmpty)
    }

    // MARK: - Recording Tests

    @Test
    func recording_keyS_emitsStopRecordingEffect_stateUnchanged() {
        let state = TUIState.recording(startedAt: Date(), captureSystemAudio: true)
        let (nextState, effects) = TUIController.reduce(state, .key("s"))
        #expect(nextState == state)
        #expect(effects == [.stopRecording])
    }

    @Test
    func recording_tick_returnsStateUnchanged_noEffects() {
        let state = TUIState.recording(startedAt: Date(), captureSystemAudio: false)
        let (nextState, effects) = TUIController.reduce(state, .tick(Date()))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    // MARK: - Recording Saved Tests

    @Test
    func recordingSaved_keyReturn_transitionsToProcessing_withRunPipelineEffect() {
        let recording = makeRecording()
        let state = TUIState.recordingSaved(recording)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        if case .processing(let rec, let statusLine) = nextState {
            #expect(rec.id == recording.id)
            #expect(statusLine == "Starting...")
        } else {
            #expect(Bool(false), "Expected .processing state")
        }
        #expect(effects == [.runPipeline(recording)])
    }

    @Test
    func recordingSaved_keyNewline_transitionsToProcessing_withRunPipelineEffect() {
        let recording = makeRecording()
        let state = TUIState.recordingSaved(recording)
        let (nextState, effects) = TUIController.reduce(state, .key("\n"))
        if case .processing(let rec, let statusLine) = nextState {
            #expect(rec.id == recording.id)
            #expect(statusLine == "Starting...")
        } else {
            #expect(Bool(false), "Expected .processing state")
        }
        #expect(effects == [.runPipeline(recording)])
    }

    @Test
    func recordingSaved_keyB_returnsToMainMenu() {
        let recording = makeRecording()
        let state = TUIState.recordingSaved(recording)
        let (nextState, effects) = TUIController.reduce(state, .key("b"))
        #expect(nextState == .mainMenu)
        #expect(effects.isEmpty)
    }

    // MARK: - Browsing Tests

    @Test
    func browsing_keyJ_incrementsSelectedIndex_clampedToLast() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B"), makeRecording(title: "C")]
        let state = TUIState.browsing(recordings: recordings, selectedIndex: 2) // Already at last
        let (nextState, effects) = TUIController.reduce(state, .key("j"))
        if case .browsing(_, let idx) = nextState {
            #expect(idx == 2) // Clamped at last index
        } else {
            #expect(Bool(false), "Expected .browsing state")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func browsing_keyK_decrementsSelectedIndex_clampedToZero() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B"), makeRecording(title: "C")]
        let state = TUIState.browsing(recordings: recordings, selectedIndex: 0) // Already at first
        let (nextState, effects) = TUIController.reduce(state, .key("k"))
        if case .browsing(_, let idx) = nextState {
            #expect(idx == 0) // Clamped at 0
        } else {
            #expect(Bool(false), "Expected .browsing state")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func browsing_keyJ_and_K_moveWithinBounds() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B"), makeRecording(title: "C")]

        // Start at index 1
        var state = TUIState.browsing(recordings: recordings, selectedIndex: 1)
        var (nextState, _) = TUIController.reduce(state, .key("j"))
        if case .browsing(_, let idx) = nextState { #expect(idx == 2) } else { #expect(Bool(false)) }

        state = nextState
        (nextState, _) = TUIController.reduce(state, .key("k"))
        if case .browsing(_, let idx) = nextState { #expect(idx == 1) } else { #expect(Bool(false)) }

        state = nextState
        (nextState, _) = TUIController.reduce(state, .key("k"))
        if case .browsing(_, let idx) = nextState { #expect(idx == 0) } else { #expect(Bool(false)) }
    }

    @Test
    func browsing_keyReturn_onNonEmpty_transitionsToProcessing_withRunPipelineEffect() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B")]
        let state = TUIState.browsing(recordings: recordings, selectedIndex: 1)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        if case .processing(let rec, let statusLine) = nextState {
            #expect(rec.id == recordings[1].id)
            #expect(statusLine == "Starting...")
        } else {
            #expect(Bool(false), "Expected .processing state")
        }
        #expect(effects == [.runPipeline(recordings[1])])
    }

    @Test
    func browsing_keyReturn_onEmpty_noOp() {
        let state = TUIState.browsing(recordings: [], selectedIndex: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func browsing_keyB_returnsToMainMenu() {
        let recordings = [makeRecording()]
        let state = TUIState.browsing(recordings: recordings, selectedIndex: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("b"))
        #expect(nextState == .mainMenu)
        #expect(effects.isEmpty)
    }

    // MARK: - Viewing Results Tests

    @Test
    func viewingResults_keyJ_incrementsScrollOffset() {
        let transcript = makeTranscript()
        let summary = makeSummary()
        let state = TUIState.viewingResults(transcript: transcript, summary: summary, scrollOffset: 5)
        let (nextState, effects) = TUIController.reduce(state, .key("j"))
        if case .viewingResults(_, _, let offset) = nextState {
            #expect(offset == 6)
        } else {
            #expect(Bool(false), "Expected .viewingResults state")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func viewingResults_keyK_decrementsScrollOffset_clampedToZero() {
        let transcript = makeTranscript()
        let summary = makeSummary()
        let state = TUIState.viewingResults(transcript: transcript, summary: summary, scrollOffset: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("k"))
        if case .viewingResults(_, _, let offset) = nextState {
            #expect(offset == 0) // Clamped at 0
        } else {
            #expect(Bool(false), "Expected .viewingResults state")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func viewingResults_keyE_emitsExportResultEffect_withMarkdownFormat() {
        let transcript = makeTranscript()
        let summary = makeSummary()
        let state = TUIState.viewingResults(transcript: transcript, summary: summary, scrollOffset: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("e"))
        #expect(nextState == state)
        #expect(effects.count == 1)
        if case .exportResult(let t, let s, let format) = effects[0] {
            #expect(t.id == transcript.id)
            #expect(s?.id == summary.id)
            #expect(format == .markdown)
        } else {
            #expect(Bool(false), "Expected .exportResult effect")
        }
    }

    @Test
    func viewingResults_keyB_returnsToMainMenu() {
        let transcript = makeTranscript()
        let state = TUIState.viewingResults(transcript: transcript, summary: nil, scrollOffset: 10)
        let (nextState, effects) = TUIController.reduce(state, .key("b"))
        #expect(nextState == .mainMenu)
        #expect(effects.isEmpty)
    }

    // MARK: - Error Message Tests

    @Test
    func errorMessage_keyB_returnsToMainMenu() {
        let state = TUIState.errorMessage("Something went wrong")
        let (nextState, effects) = TUIController.reduce(state, .key("b"))
        #expect(nextState == .mainMenu)
        #expect(effects.isEmpty)
    }

    // MARK: - Unhandled / Default Tests

    @Test
    func mainMenu_unhandledKey_returnsStateUnchanged_noEffects() {
        let (nextState, effects) = TUIController.reduce(.mainMenu, .key("z"))
        #expect(nextState == .mainMenu)
        #expect(effects.isEmpty)
    }

    @Test
    func recording_unhandledKey_returnsStateUnchanged_noEffects() {
        let state = TUIState.recording(startedAt: Date(), captureSystemAudio: true)
        let (nextState, effects) = TUIController.reduce(state, .key("x"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }
}
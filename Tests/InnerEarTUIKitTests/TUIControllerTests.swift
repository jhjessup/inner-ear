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

    /// Wrap a list of recordings into `RecordingListEntry` values for the
    /// newer `.list(entries:...)` shape — defaults to `hasAudio: true`
    /// (the most permissive default for tests that just want to exercise
    /// list navigation / Enter → pipeline, which now requires audio to
    /// be present). Pass `hasAudio: false` to opt into the "neither
    /// audio nor transcript" no-op-Enter case.
    private func makeEntries(_ recordings: [Recording], hasAudio: Bool = true) -> [RecordingListEntry] {
        recordings.map { rec in
            RecordingListEntry(
                recording: rec,
                hasAudio: hasAudio,
                transcript: nil,
                summary: nil,
                transcriptFileURL: nil
            )
        }
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

    // MARK: - Tick is always a no-op

    @Test
    func tick_alwaysReturnsStateUnchanged_noEffects() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 5)
        )
        let (nextState, effects) = TUIController.reduce(state, .tick(Date()))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    // MARK: - Tab toggles focused pane (both directions)

    @Test
    func tab_navigationToDetail() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("\t"))
        #expect(nextState.focusedPane == .detail)
        #expect(effects.isEmpty)
    }

    @Test
    func tab_detailToNavigation() {
        let state = TUIState(focusedPane: .detail, selectedSection: 1)
        let (nextState, effects) = TUIController.reduce(state, .key("\t"))
        #expect(nextState.focusedPane == .navigation)
        #expect(effects.isEmpty)
    }

    // MARK: - Nav-pane j/k clamping

    @Test
    func navKey_j_incrementsSelectedSection() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0)
        let (nextState, _) = TUIController.reduce(state, .key("j"))
        #expect(nextState.selectedSection == 1)
    }

    @Test
    func navKey_k_decrementsSelectedSection() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 2)
        let (nextState, _) = TUIController.reduce(state, .key("k"))
        #expect(nextState.selectedSection == 1)
    }

    @Test
    func navKey_j_clampsAtTwo() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 2)
        let (nextState, _) = TUIController.reduce(state, .key("j"))
        #expect(nextState.selectedSection == 2)
    }

    @Test
    func navKey_k_clampsAtZero() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0)
        let (nextState, _) = TUIController.reduce(state, .key("k"))
        #expect(nextState.selectedSection == 0)
    }

    // MARK: - Nav Enter into each section

    @Test
    func navEnter_section0_noEffects_focusesDetail() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState.focusedPane == .detail)
        #expect(nextState.selectedSection == 0)
        #expect(effects.isEmpty)
    }

    @Test
    func navEnter_section1_emitsLoadRecordings_focusesDetail() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 1)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState.focusedPane == .detail)
        #expect(nextState.selectedSection == 1)
        #expect(effects == [.loadRecordings])
    }

    @Test
    func navEnter_section2_emitsLoadConfigStatus_focusesDetail() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 2)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState.focusedPane == .detail)
        #expect(nextState.selectedSection == 2)
        #expect(effects == [.loadConfigStatus])
    }

    // MARK: - Nav q emits .quit

    @Test
    func navKey_q_emitsQuit() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0)
        let (nextState, effects) = TUIController.reduce(state, .key("q"))
        #expect(nextState == state)
        #expect(effects == [.quit])
    }

    // MARK: - Esc from nav-focused resets each section's sub-state

    @Test
    func esc_whileRecordPrompting_resetsToIdle() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0, record: .prompting)
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.focusedPane == .navigation)
        #expect(nextState.record == .idle)
        #expect(effects.isEmpty)
    }

    @Test
    func esc_whileRecordSaved_resetsToIdle() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0, record: .saved(makeRecording()))
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.record == .idle)
        #expect(effects.isEmpty)
    }

    @Test
    func esc_whileRecordIdle_isNoOp() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0, record: .idle)
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.record == .idle)
        #expect(effects.isEmpty)
    }

    @Test
    func esc_whileViewingResults_resetsToEmptyList_noLoadEffect() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 3)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        if case .list(let recs, let idx) = nextState.recordings {
            #expect(recs.isEmpty)
            #expect(idx == 0)
        } else {
            #expect(Bool(false), "Expected .list after Esc")
        }
        #expect(effects.isEmpty, "Esc should NOT emit .loadRecordings (plan: pure local reset)")
    }

    @Test
    func esc_whileList_keepsList_noEffects() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B")]
        let entries = makeEntries(recordings)
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 1,
            recordings: .list(entries: entries, selectedIndex: 1)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.recordings == .list(entries: entries, selectedIndex: 1))
        #expect(effects.isEmpty)
    }

    @Test
    func esc_whileProcessing_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 1,
            recordings: .processing(recording: makeRecording(), statusLine: "Transcribing...")
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        if case .processing(_, let statusLine) = nextState.recordings {
            #expect(statusLine == "Transcribing...")
        } else {
            #expect(Bool(false), "Expected .processing preserved")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func esc_whileSettingsEditing_emitsLoadConfigStatus_resetsToPlaceholder() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 2,
            settings: .editing(currentInput: "/tmp/newpath")
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        if case .viewing(let resolvedPath, let source) = nextState.settings {
            #expect(resolvedPath == "")
            #expect(source == .defaultLocation)
        } else {
            #expect(Bool(false), "Expected .viewing placeholder after Esc")
        }
        #expect(effects == [.loadConfigStatus])
    }

    @Test
    func esc_whileSettingsViewing_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 2,
            settings: .viewing(resolvedPath: "/data", source: .configFile)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.settings == state.settings)
        #expect(effects.isEmpty)
    }

    // MARK: - Modal: swallows all but Enter/Esc

    @Test
    func modal_keyEnter_clearsModal() {
        let state = TUIState(modal: .error("disk full"))
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState.modal == nil)
        #expect(effects.isEmpty)
    }

    @Test
    func modal_keyNewline_clearsModal() {
        let state = TUIState(modal: .error("disk full"))
        let (nextState, _) = TUIController.reduce(state, .key("\n"))
        #expect(nextState.modal == nil)
    }

    @Test
    func modal_keyEsc_clearsModal() {
        let state = TUIState(modal: .error("disk full"))
        let (nextState, _) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.modal == nil)
    }

    @Test
    func modal_otherKey_isSwallowed() {
        let state = TUIState(focusedPane: .navigation, selectedSection: 0, modal: .error("disk full"))
        let (nextState, effects) = TUIController.reduce(state, .key("q"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func modal_tab_isSwallowed() {
        let state = TUIState(focusedPane: .navigation, modal: .error("disk full"))
        let (nextState, effects) = TUIController.reduce(state, .key("\t"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    // MARK: - Active-recording lock (Task 4 case 2)

    @Test
    func recordingLock_tab_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\t"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordingLock_navJ_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 0,
            record: .recording(startedAt: Date(), captureSystemAudio: false)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("j"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordingLock_navK_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 2,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("k"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordingLock_navEnter_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 0,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordingLock_q_isNoOp() {
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 0,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("q"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordingLock_s_emitsStopRecording_stateUnchanged() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 0,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("s"))
        #expect(nextState == state)
        #expect(effects == [.stopRecording])
    }

    @Test
    func recordingLock_esc_emitsStopRecording_stateUnchanged() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 0,
            record: .recording(startedAt: Date(), captureSystemAudio: true)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState == state)
        #expect(effects == [.stopRecording])
    }

    // MARK: - Section 0: Record

    @Test
    func record_idle_enter_transitionsToPrompting() {
        let state = TUIState(focusedPane: .detail, selectedSection: 0, record: .idle)
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState.record == .prompting)
        #expect(effects.isEmpty)
    }

    @Test
    func record_prompting_y_startsRecordingWithSystemAudioTrue() {
        let state = TUIState(focusedPane: .detail, selectedSection: 0, record: .prompting)
        let (nextState, effects) = TUIController.reduce(state, .key("y"))
        if case .recording(_, let captureSystemAudio) = nextState.record {
            #expect(captureSystemAudio == true)
        } else {
            #expect(Bool(false), "Expected .recording")
        }
        #expect(effects == [.startRecording(captureSystemAudio: true)])
    }

    @Test
    func record_prompting_n_startsRecordingWithSystemAudioFalse() {
        let state = TUIState(focusedPane: .detail, selectedSection: 0, record: .prompting)
        let (nextState, effects) = TUIController.reduce(state, .key("n"))
        if case .recording(_, let captureSystemAudio) = nextState.record {
            #expect(captureSystemAudio == false)
        } else {
            #expect(Bool(false), "Expected .recording")
        }
        #expect(effects == [.startRecording(captureSystemAudio: false)])
    }

    @Test
    func record_saved_enter_startsPipeline_andJumpsToRecordingsSection() {
        let recording = makeRecording()
        let state = TUIState(focusedPane: .detail, selectedSection: 0, record: .saved(recording))
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        // The specific assertion the design review called out: all four
        // must be true in the same reduce() call.
        #expect(nextState.selectedSection == 1)
        if case .processing(let rec, let statusLine) = nextState.recordings {
            #expect(rec.id == recording.id)
            #expect(statusLine == "Starting...")
        } else {
            #expect(Bool(false), "Expected .processing on recordings")
        }
        #expect(nextState.record == .idle)
        #expect(nextState.focusedPane == .detail)
        #expect(effects == [.runPipeline(recording)])
    }

    // MARK: - Section 1: Recordings

    @Test
    func recordings_list_j_incrementsSelectedIndex() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B"), makeRecording(title: "C")]
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: makeEntries(recordings), selectedIndex: 0)
        )
        let (nextState, _) = TUIController.reduce(state, .key("j"))
        if case .list(_, let idx) = nextState.recordings {
            #expect(idx == 1)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordings_list_j_clampsAtLast() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B"), makeRecording(title: "C")]
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: makeEntries(recordings), selectedIndex: 2)
        )
        let (nextState, _) = TUIController.reduce(state, .key("j"))
        if case .list(_, let idx) = nextState.recordings {
            #expect(idx == 2)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordings_list_k_decrementsSelectedIndex() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B"), makeRecording(title: "C")]
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: makeEntries(recordings), selectedIndex: 2)
        )
        let (nextState, _) = TUIController.reduce(state, .key("k"))
        if case .list(_, let idx) = nextState.recordings {
            #expect(idx == 1)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordings_list_k_clampsAtZero() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B")]
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: makeEntries(recordings), selectedIndex: 0)
        )
        let (nextState, _) = TUIController.reduce(state, .key("k"))
        if case .list(_, let idx) = nextState.recordings {
            #expect(idx == 0)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordings_list_enter_onEntryWithAudioNoTranscript_showsGeneratePrompt() {
        // Entries from makeEntries default to hasAudio: true, transcript: nil.
        // Enter must NOT jump straight to the pipeline anymore — it has to
        // confirm first (this replaces the old runsPipeline-directly test,
        // which tested behavior this feature deliberately changed).
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B")]
        let entries = makeEntries(recordings)
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: entries, selectedIndex: 1)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        if case .confirmGenerateTranscript(let e, let idx) = nextState.recordings {
            #expect(e == entries)
            #expect(idx == 1)
        } else {
            #expect(Bool(false), "Expected .confirmGenerateTranscript")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func recordings_list_enter_onEntryWithExistingTranscript_jumpsStraightToResults() {
        let recording = makeRecording(title: "Has transcript")
        let transcript = makeTranscript()
        let summary = makeSummary()
        let entry = RecordingListEntry(
            recording: recording,
            hasAudio: true,
            transcript: transcript,
            summary: summary,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [entry], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        if case .viewingResults(let t, let s, let offset) = nextState.recordings {
            #expect(t == transcript)
            #expect(s == summary)
            #expect(offset == 0)
        } else {
            #expect(Bool(false), "Expected .viewingResults directly, no confirm step")
        }
        #expect(effects.isEmpty, "Already-resolved transcript/summary needs no effect")
    }

    @Test
    func recordings_list_enter_onEntryWithNeitherAudioNorTranscript_isNoOp() {
        let entry = RecordingListEntry(
            recording: makeRecording(),
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
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordings_list_enter_onEmpty_isNoOp() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    @Test
    func recordings_list_d_onNonEmpty_showsDeletePrompt() {
        let entries = makeEntries([makeRecording(title: "A")])
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: entries, selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("d"))
        if case .confirmDelete(let e, let idx) = nextState.recordings {
            #expect(e == entries)
            #expect(idx == 0)
        } else {
            #expect(Bool(false), "Expected .confirmDelete")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func recordings_list_d_onEmpty_isNoOp() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .list(entries: [], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("d"))
        #expect(nextState == state)
        #expect(effects.isEmpty)
    }

    // MARK: - Section 1: confirmGenerateTranscript

    @Test
    func confirmGenerateTranscript_y_startsPipeline() {
        let recordings = [makeRecording(title: "A"), makeRecording(title: "B")]
        let entries = makeEntries(recordings)
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmGenerateTranscript(entries: entries, selectedIndex: 1)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("y"))
        if case .processing(let rec, let statusLine) = nextState.recordings {
            #expect(rec.id == recordings[1].id)
            #expect(statusLine == "Starting...")
        } else {
            #expect(Bool(false), "Expected .processing")
        }
        #expect(effects == [.runPipeline(recordings[1])])
    }

    @Test
    func confirmGenerateTranscript_n_returnsToList() {
        let entries = makeEntries([makeRecording(title: "A")])
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmGenerateTranscript(entries: entries, selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("n"))
        #expect(nextState.recordings == .list(entries: entries, selectedIndex: 0))
        #expect(effects.isEmpty)
    }

    @Test
    func confirmGenerateTranscript_esc_returnsToList() {
        let entries = makeEntries([makeRecording(title: "A")])
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmGenerateTranscript(entries: entries, selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.recordings == .list(entries: entries, selectedIndex: 0))
        #expect(effects.isEmpty)
    }

    // MARK: - Section 1: confirmDelete

    @Test
    func confirmDelete_a_withAudio_emitsDeleteAudioThenLoadRecordings() {
        let entry = RecordingListEntry(
            recording: makeRecording(),
            hasAudio: true,
            transcript: nil,
            summary: nil,
            transcriptFileURL: nil
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmDelete(entries: [entry], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("a"))
        #expect(nextState.recordings == .list(entries: [entry], selectedIndex: 0))
        #expect(effects == [.deleteAudio(entry.recording), .loadRecordings])
    }

    @Test
    func confirmDelete_a_withoutAudio_isNoOpEffect() {
        let entry = RecordingListEntry(
            recording: makeRecording(),
            hasAudio: false,
            transcript: makeTranscript(),
            summary: nil,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmDelete(entries: [entry], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("a"))
        #expect(nextState.recordings == .list(entries: [entry], selectedIndex: 0))
        #expect(effects.isEmpty)
    }

    @Test
    func confirmDelete_t_withTranscript_emitsDeleteTranscriptThenLoadRecordings() {
        let transcript = makeTranscript()
        let entry = RecordingListEntry(
            recording: makeRecording(),
            hasAudio: true,
            transcript: transcript,
            summary: nil,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmDelete(entries: [entry], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("t"))
        #expect(nextState.recordings == .list(entries: [entry], selectedIndex: 0))
        #expect(effects == [.deleteTranscript(transcript), .loadRecordings])
    }

    @Test
    func confirmDelete_b_withBoth_emitsBothDeletesThenLoadRecordings() {
        let transcript = makeTranscript()
        let recording = makeRecording()
        let entry = RecordingListEntry(
            recording: recording,
            hasAudio: true,
            transcript: transcript,
            summary: nil,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmDelete(entries: [entry], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("b"))
        #expect(nextState.recordings == .list(entries: [entry], selectedIndex: 0))
        #expect(effects == [.deleteAudio(recording), .deleteTranscript(transcript), .loadRecordings])
    }

    @Test
    func confirmDelete_esc_cancelsWithNoEffects() {
        let entry = RecordingListEntry(
            recording: makeRecording(),
            hasAudio: true,
            transcript: makeTranscript(),
            summary: nil,
            transcriptFileURL: URL(fileURLWithPath: "/tmp/t.json")
        )
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .confirmDelete(entries: [entry], selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.recordings == .list(entries: [entry], selectedIndex: 0))
        #expect(effects.isEmpty)
    }

    // MARK: - Esc (global) from the two new confirm sub-states reverts to .list

    @Test
    func globalEsc_fromConfirmGenerateTranscript_revertsToList() {
        let entries = makeEntries([makeRecording(title: "A")])
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 1,
            recordings: .confirmGenerateTranscript(entries: entries, selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.recordings == .list(entries: entries, selectedIndex: 0))
        #expect(effects.isEmpty)
    }

    @Test
    func globalEsc_fromConfirmDelete_revertsToList() {
        let entries = makeEntries([makeRecording(title: "A")])
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 1,
            recordings: .confirmDelete(entries: entries, selectedIndex: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        #expect(nextState.recordings == .list(entries: entries, selectedIndex: 0))
        #expect(effects.isEmpty)
    }

    @Test
    func recordings_viewingResults_j_incrementsUnclamped() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 5)
        )
        let (nextState, _) = TUIController.reduce(state, .key("j"))
        if case .viewingResults(_, _, let offset) = nextState.recordings {
            #expect(offset == 6)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordings_viewingResults_k_clampsAtZero() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: makeTranscript(), summary: nil, scrollOffset: 0)
        )
        let (nextState, _) = TUIController.reduce(state, .key("k"))
        if case .viewingResults(_, _, let offset) = nextState.recordings {
            #expect(offset == 0)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordings_viewingResults_e_emitsExportMarkdown() {
        let transcript = makeTranscript()
        let summary = makeSummary()
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(transcript: transcript, summary: summary, scrollOffset: 0)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("e"))
        #expect(nextState == state)
        #expect(effects == [.exportResult(transcript: transcript, summary: summary, format: .markdown)])
    }

    // MARK: - Section 2: Settings

    @Test
    func settings_viewing_e_entersEditingWithPrefilledInput() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .viewing(resolvedPath: "/data/inner", source: .configFile)
        )
        let (nextState, effects) = TUIController.reduce(state, .key("e"))
        if case .editing(let input) = nextState.settings {
            #expect(input == "/data/inner")
        } else {
            #expect(Bool(false), "Expected .editing")
        }
        #expect(effects.isEmpty)
    }

    @Test
    func settings_editing_printableChar_appends() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .editing(currentInput: "/tmp")
        )
        let (nextState, effects) = TUIController.reduce(state, .key("a"))
        if case .editing(let input) = nextState.settings {
            #expect(input == "/tmpa")
        } else {
            #expect(Bool(false))
        }
        #expect(effects.isEmpty)
    }

    @Test
    func settings_editing_backspace_removesLastChar() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .editing(currentInput: "/tmp/x")
        )
        let (nextState, _) = TUIController.reduce(state, .key("\u{7F}"))
        if case .editing(let input) = nextState.settings {
            #expect(input == "/tmp/")
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func settings_editing_backspace_onEmpty_isSafe() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .editing(currentInput: "")
        )
        let (nextState, _) = TUIController.reduce(state, .key("\u{7F}"))
        if case .editing(let input) = nextState.settings {
            #expect(input == "")
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func settings_editing_enter_emitsSaveDataDirectory() {
        let state = TUIState(
            focusedPane: .detail,
            selectedSection: 2,
            settings: .editing(currentInput: "/new/data")
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\r"))
        // state.settings stays .editing (run loop overwrites after the save
        // completes); only the effect is emitted.
        if case .editing(let input) = nextState.settings {
            #expect(input == "/new/data")
        } else {
            #expect(Bool(false))
        }
        #expect(effects == [.saveDataDirectory("/new/data")])
    }

    @Test
    func settings_editing_esc_emitsLoadConfigStatus() {
        // Per TASK 4's documented reasoning: Esc during .editing cannot
        // reconstruct the pre-edit .viewing snapshot from in-state data
        // alone, so it reuses .loadConfigStatus (the same effect emitted
        // when first entering Settings) and resets settings to a harmless
        // placeholder; the run loop's .loadConfigStatus handler will
        // overwrite it with the real current (unsaved-edit-discarded)
        // resolved path/source before the next render.
        let state = TUIState(
            focusedPane: .navigation,
            selectedSection: 2,
            settings: .editing(currentInput: "/tmp/typed")
        )
        let (nextState, effects) = TUIController.reduce(state, .key("\u{1B}"))
        if case .viewing(let resolvedPath, let source) = nextState.settings {
            #expect(resolvedPath == "")
            #expect(source == .defaultLocation)
        } else {
            #expect(Bool(false), "Expected placeholder .viewing after Esc")
        }
        #expect(effects == [.loadConfigStatus])
    }
}

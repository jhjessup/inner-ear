import Foundation
import InnerEarCore

/// Pure, synchronous state machine for the TUI.
///
/// `reduce(state, event)` returns the next state plus zero or more effects.
/// It does **not** execute effects — it only declares *what* should happen.
/// The run loop (in `InnerEarCLI/TUIRunLoop.swift`) is responsible for
/// executing each effect and updating state based on the async result.
///
/// `reduce` is written as a sequence of `if`/`guard` early-returns whose
/// order is the documented precedence (modal swallow, then active-recording
/// lock, then Tab, then Esc, then nav-focused, then detail-focused). The
/// per-case body decides the next state and effects; an unhandled event
/// falls through to the bottom of the function and returns the state
/// unchanged with no effects.
public enum TUIController {

    /// Sentinel characters `readKeyOrArrowNonBlocking()` (InnerEarCLI/TerminalIO.swift)
    /// maps the Left/Right ANSI arrow-key escape sequences to. Chosen from the
    /// Unicode Private Use Area specifically because no real keypress can ever
    /// produce them, so they can be treated as global, Tab/Esc-like control
    /// keys without any risk of shadowing literal typed text (see the case-3.5
    /// comment in `reduce(_:_:)`). Public so `InnerEarCLI` can use the same
    /// literals when emitting `.key` events.
    public static let leftArrowKey: Character = "\u{E000}"
    public static let rightArrowKey: Character = "\u{E001}"

    /// PUA sentinels for PageUp/PageDown/Home/End (`ESC[5~`/`ESC[6~`/`ESC[1~`/`ESC[4~`
    /// — see `readKeyOrArrowNonBlocking()` in InnerEarCLI/TerminalIO.swift).
    /// Deliberately NOT aliased to the existing letter mnemonics (`"b"`/`" "`/`"g"`/`"G"`)
    /// even though they trigger the identical behavior in `.viewingResults`:
    /// `"b"` already means something destructive elsewhere (`confirmDelete`'s
    /// "delete Both audio and transcript"), so a real PageUp keypress must
    /// never be able to fire it in an unrelated screen. Same reasoning as
    /// `leftArrowKey`/`rightArrowKey` — a real keypress can never produce a
    /// PUA codepoint, so aliasing is done explicitly per-state (see the
    /// `.viewingResults` case in `reduce(_:_:)`) instead of by character reuse.
    public static let pageUpKey: Character = "\u{E002}"
    public static let pageDownKey: Character = "\u{E003}"
    public static let homeKey: Character = "\u{E004}"
    public static let endKey: Character = "\u{E005}"

    /// Fixed step size for the transcript pager's space/b page-forward and
    /// page-backward keys (see `.viewingResults` in `reduce(_:_:)`). The
    /// reducer is pure and has no access to the terminal's actual height, so
    /// this is a fixed approximation of "one screenful" rather than an exact
    /// page — real pagers (less/more) size a page from the terminal height.
    static let pagerPageStep = 10

    /// Overflow-safe "scroll to bottom" sentinel for the transcript pager's
    /// `G` key. Large enough that `renderRecordingsResults`'s render-time
    /// clamp always treats it as "past the end" for any realistic
    /// transcript, but far below `Int.max` so a later `j` press (scrollOffset
    /// + 1) can never trap on overflow.
    static let pagerBottomSentinel = 1_000_000_000

    /// Apply one event to the current state, returning the new state and any
    /// effects that the run loop should execute.
    ///
    /// - Parameters:
    ///   - state: Current TUI state.
    ///   - event: Incoming event (keypress or tick).
    /// - Returns: `(nextState, effects)` where `effects` may be empty.
    public static func reduce(_ state: TUIState, _ event: TUIEvent) -> (TUIState, [TUIEffect]) {
        // Tick events never cause transitions; the renderer recomputes the
        // recording elapsed time from wall-clock `Date()` itself.
        guard case .key(let key) = event else {
            return (state, [])
        }

        // 1. Modal check: while a modal is showing, swallow all keys except
        // Enter and Esc, which dismiss it.
        if state.modal != nil {
            if key == "\r" || key == "\n" || key == "\u{1B}" {
                var s = state
                s.modal = nil
                return (s, [])
            }
            return (state, [])
        }

        // 2. Active-recording lock: while a recording is in progress, the
        // only meaningful keys are 's' and Esc, which both stop the capture.
        // Everything else (Tab, j, k, Enter, q, ...) is a hard no-op so the
        // user cannot accidentally abandon a live capture.
        if case .recording = state.record {
            if key == "s" || key == "\u{1B}" {
                return (state, [.stopRecording])
            }
            return (state, [])
        }

        // 3. Tab toggles focus between nav pane and detail pane. No effects.
        if key == "\t" {
            var s = state
            s.focusedPane = (state.focusedPane == .navigation) ? .detail : .navigation
            return (s, [])
        }

        // 3.5. Left arrow always pulls focus back to the nav pane, mirroring
        // Tab's "no effects, just flip focus" behavior — never destructive
        // to the current section's sub-state (unlike Esc, which resets it).
        // No-op if the nav pane is already focused. Right arrow's symmetric
        // case is folded into case 5 below (see the comment there) because
        // "enter the detail pane" and "open the selected nav item" are the
        // same effect-triggering transition Enter already performs there.
        //
        // `leftArrowKey`/`rightArrowKey` are the Unicode Private-Use-Area
        // sentinels `readKeyOrArrowNonBlocking()` (in InnerEarCLI/TerminalIO.swift)
        // maps the Left/Right ANSI escape sequences to. Deliberately NOT
        // reusing printable letters the way Up/Down reuse 'k'/'j' elsewhere
        // in this file: 'k'/'j' are only ever interpreted inside specific
        // list/scroll sub-states, but pane-switching needs to be a GLOBAL,
        // Tab-like control key — and this project's data-directory path
        // editor (Settings, case 2) accepts arbitrary printable text, which
        // could easily contain 'h'/'l' (e.g. a path with "jhjessup" in it).
        // A PUA codepoint can never arrive from a real keypress, so it's
        // safe to treat as privileged without shadowing typed text.
        if key == leftArrowKey, state.focusedPane == .detail {
            var s = state
            s.focusedPane = .navigation
            return (s, [])
        }

        // 4. Esc (when not recording and not in a modal): reset the
        // current section's sub-state to its safe/idle form, and pull
        // focus back to the nav pane.
        if key == "\u{1B}" {
            var s = state
            s.focusedPane = .navigation
            switch s.selectedSection {
            case 0:
                // Record: idle/prompting/saved -> idle. .recording is handled
                // by case 2 so it never reaches here.
                if case .idle = s.record { /* no-op */ }
                else { s.record = .idle }
            case 1:
                // Recordings: .list stays as-is (don't clobber a populated
                // list). .processing is a no-op so we don't corrupt state
                // mid-pipeline. .confirmGenerateTranscript and .confirmDelete
                // revert to .list using the entries/selectedIndex already in
                // hand (same data the per-section reducer would have used
                // for 'n' or Esc) — preserves any in-progress browsing state.
                //
                // .viewingResults previously reset to an EMPTY .list with no
                // reload effect, on the theory that the next nav Enter would
                // refresh it — but Esc from results is exactly the path a
                // user takes right after recording+processing something new,
                // and leaving them at a blank "No recordings yet." until
                // they leave and re-enter the section reads as data loss,
                // not a lazy-reload optimization. Emit `.loadRecordings` so
                // the list is genuinely fresh (and includes what was just
                // processed) the moment Esc is pressed, not on next entry.
                switch s.recordings {
                case .viewingResults:
                    s.recordings = .list(entries: [], selectedIndex: 0)
                    return (s, [.loadRecordings])
                case .confirmGenerateTranscript(let entries, let selectedIndex):
                    s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                case .confirmDelete(let entries, let selectedIndex):
                    s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                case .list, .processing:
                    break
                }
            case 2:
                // Settings: editing -> discard the in-progress edit by
                // emitting a fresh .loadConfigStatus (which the run loop
                // will fulfill by overwriting state.settings with the real
                // on-disk .viewing values), and clear the stale .editing
                // state with a harmless placeholder. This reuses an
                // existing effect instead of inventing new state-tracking
                // machinery to remember the pre-edit .viewing snapshot.
                //
                // Tab-away-during-editing is allowed by case 3 (Tab just
                // flips focusedPane, doesn't touch settings). When the user
                // later returns to Settings via nav Enter, case 5's
                // selectedSection==2 rule re-emits .loadConfigStatus at
                // that point, which overwrites the stale .editing state
                // with a fresh .viewing — so the abandoned edit is
                // naturally discarded next time Settings is actually viewed.
                if case .editing = s.settings {
                    s.settings = .viewing(resolvedPath: "", source: .defaultLocation)
                    return (s, [.loadConfigStatus])
                }
            default:
                break
            }
            return (s, [])
        }

        // 5. Nav-pane focused: j/k to move selection, Enter to open,
        // q to quit.
        if state.focusedPane == .navigation {
            switch key {
            case "j":
                var s = state
                s.selectedSection = min(state.selectedSection + 1, 2)
                return (s, [])
            case "k":
                var s = state
                s.selectedSection = max(state.selectedSection - 1, 0)
                return (s, [])
            case "\r", "\n", rightArrowKey:
                // Right arrow reuses this exact branch (rather than a plain
                // focus flip like Tab/Left-arrow) because sections 1 and 2
                // only populate their detail pane via these load effects —
                // a bare focus flip would land on a stale/empty pane.
                var s = state
                s.focusedPane = .detail
                switch state.selectedSection {
                case 1:
                    return (s, [.loadRecordings])
                case 2:
                    return (s, [.loadConfigStatus])
                default:
                    return (s, [])
                }
            case "q":
                return (state, [.quit])
            default:
                return (state, [])
            }
        }

        // 6. Detail-pane focused: dispatch on the current section.
        switch state.selectedSection {
        case 0:
            return reduceRecord(state: state, key: key)
        case 1:
            return reduceRecordings(state: state, key: key)
        case 2:
            return reduceSettings(state: state, key: key)
        default:
            return (state, [])
        }
    }

    // MARK: - Per-section reducers

    /// Section 0 (Record) — match on `state.record`.
    private static func reduceRecord(state: TUIState, key: Character) -> (TUIState, [TUIEffect]) {
        switch state.record {
        case .idle:
            if key == "\r" || key == "\n" {
                var s = state
                s.record = .prompting
                return (s, [])
            }
            return (state, [])

        case .prompting:
            if key == "y" {
                var s = state
                s.record = .recording(startedAt: Date(), captureSystemAudio: true)
                return (s, [.startRecording(captureSystemAudio: true)])
            }
            if key == "n" {
                var s = state
                s.record = .recording(startedAt: Date(), captureSystemAudio: false)
                return (s, [.startRecording(captureSystemAudio: false)])
            }
            return (state, [])

        case .recording:
            // Unreachable here: case 2 short-circuits before this dispatcher.
            return (state, [])

        case .saved(let recording):
            if key == "\r" || key == "\n" {
                var s = state
                s.selectedSection = 1
                s.recordings = .processing(recording: recording, statusLine: "Starting...", stepIndex: 0)
                s.record = .idle
                // focusedPane stays .detail — the user is still looking at
                // a detail pane, just section 1 instead of 0.
                return (s, [.runPipeline(recording)])
            }
            return (state, [])
        }
    }

    /// Section 1 (Recordings) — match on `state.recordings`.
    private static func reduceRecordings(state: TUIState, key: Character) -> (TUIState, [TUIEffect]) {
        switch state.recordings {
        case .list(let entries, let selectedIndex):
            switch key {
            case "j":
                var s = state
                s.recordings = .list(
                    entries: entries,
                    selectedIndex: min(selectedIndex + 1, max(0, entries.count - 1))
                )
                return (s, [])
            case "k":
                var s = state
                s.recordings = .list(
                    entries: entries,
                    selectedIndex: max(selectedIndex - 1, 0)
                )
                return (s, [])
            case "\r", "\n":
                guard !entries.isEmpty else { return (state, []) }
                let entry = entries[selectedIndex]
                var s = state
                if let transcript = entry.transcript {
                    // Already transcribed — jump straight to the viewer,
                    // no effect needed (transcript + summary are already
                    // resolved into the entry, so this is a pure state
                    // transition).
                    s.recordings = .viewingResults(
                        transcript: transcript,
                        summary: entry.summary,
                        scrollOffset: 0
                    )
                    return (s, [])
                } else if entry.hasAudio {
                    // Has audio but no transcript yet — confirm before
                    // kicking off the (potentially long) pipeline.
                    s.recordings = .confirmGenerateTranscript(
                        entries: entries,
                        selectedIndex: selectedIndex
                    )
                    return (s, [])
                } else {
                    // Neither audio nor transcript — a transient edge case
                    // that shouldn't normally persist in the list. No-op.
                    return (state, [])
                }
            case "d":
                guard !entries.isEmpty else { return (state, []) }
                var s = state
                s.recordings = .confirmDelete(
                    entries: entries,
                    selectedIndex: selectedIndex
                )
                return (s, [])
            default:
                return (state, [])
            }

        case .confirmGenerateTranscript(let entries, let selectedIndex):
            switch key {
            case "y":
                let recording = entries[selectedIndex].recording
                var s = state
                s.recordings = .processing(recording: recording, statusLine: "Starting...", stepIndex: 0)
                return (s, [.runPipeline(recording)])
            case "n", "\u{1B}":
                var s = state
                s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                return (s, [])
            default:
                return (state, [])
            }

        case .confirmDelete(let entries, let selectedIndex):
            let entry = entries[selectedIndex]
            switch key {
            case "a":
                var s = state
                s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                if entry.hasAudio {
                    return (s, [.deleteAudio(entry.recording), .loadRecordings])
                }
                return (s, [])
            case "t":
                var s = state
                s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                if let transcript = entry.transcript {
                    return (s, [.deleteTranscript(transcript), .loadRecordings])
                }
                return (s, [])
            case "b":
                var s = state
                s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                var effects: [TUIEffect] = []
                if entry.hasAudio {
                    effects.append(.deleteAudio(entry.recording))
                }
                if let transcript = entry.transcript {
                    effects.append(.deleteTranscript(transcript))
                }
                if !effects.isEmpty {
                    effects.append(.loadRecordings)
                }
                return (s, effects)
            case "\u{1B}":
                var s = state
                s.recordings = .list(entries: entries, selectedIndex: selectedIndex)
                return (s, [])
            default:
                return (state, [])
            }

        case .processing:
            // No keys do anything while the pipeline is running.
            return (state, [])

        case .viewingResults(let transcript, let summary, let scrollOffset):
            // Pager-style navigation (less(1)/more(1) conventions): j/k step
            // one line, space/b page forward/backward, g/G jump to the
            // top/bottom. None of these clamp upward here — same as the
            // pre-existing j behavior, the renderer clamps against the real
            // content height at render time (`clampedOffset` in
            // `renderRecordingsResults`), since the reducer has no access to
            // terminal size. `pagerPageStep` is therefore a fixed
            // approximation of "one screenful," not an exact page height.
            switch key {
            case "j":
                var s = state
                s.recordings = .viewingResults(
                    transcript: transcript,
                    summary: summary,
                    scrollOffset: scrollOffset + 1
                )
                return (s, [])
            case "k":
                var s = state
                s.recordings = .viewingResults(
                    transcript: transcript,
                    summary: summary,
                    scrollOffset: max(scrollOffset - 1, 0)
                )
                return (s, [])
            case " ", Self.pageDownKey:
                var s = state
                s.recordings = .viewingResults(
                    transcript: transcript,
                    summary: summary,
                    scrollOffset: scrollOffset + Self.pagerPageStep
                )
                return (s, [])
            case "b", Self.pageUpKey:
                var s = state
                s.recordings = .viewingResults(
                    transcript: transcript,
                    summary: summary,
                    scrollOffset: max(scrollOffset - Self.pagerPageStep, 0)
                )
                return (s, [])
            case "g", Self.homeKey:
                var s = state
                s.recordings = .viewingResults(transcript: transcript, summary: summary, scrollOffset: 0)
                return (s, [])
            case "G", Self.endKey:
                var s = state
                // A large-but-overflow-safe sentinel, not Int.max: the
                // renderer clamps it down to the real bottom at render time,
                // but j/k arithmetic on `scrollOffset` elsewhere in this
                // case must never risk an Int overflow trap if pressed again
                // afterward.
                s.recordings = .viewingResults(transcript: transcript, summary: summary, scrollOffset: Self.pagerBottomSentinel)
                return (s, [])
            case "e":
                return (state, [.exportResult(transcript: transcript, summary: summary, format: .markdown)])
            default:
                return (state, [])
            }
        }
    }

    /// Section 2 (Settings) — match on `state.settings`.
    ///
    /// Editing model: `e` enters `.editing` prefilled with the current
    /// resolved path. Printable ASCII characters append; backspace
    /// (`\u{7F}`) removes the last char (safe on empty). Enter emits
    /// `.saveDataDirectory(currentInput)`, leaving `state.settings` as
    /// `.editing` so the user can see their in-flight input while the
    /// save runs; the run loop overwrites with `.viewing` once the new
    /// status is read back. Esc during editing discards the edit and
    /// re-emits `.loadConfigStatus` (see the case-4 comment in
    /// `reduce(_:_:)` for why this is the right effect).
    private static func reduceSettings(state: TUIState, key: Character) -> (TUIState, [TUIEffect]) {
        switch state.settings {
        case .viewing(let resolvedPath, _):
            if key == "e" {
                var s = state
                s.settings = .editing(currentInput: resolvedPath)
                return (s, [])
            }
            return (state, [])

        case .editing(let currentInput):
            if key == "\r" || key == "\n" {
                // Leave state.settings as .editing — the run loop will
                // transition to .viewing once .saveDataDirectory completes
                // and the new resolved path is confirmed by a fresh
                // .loadConfigStatus call.
                return (state, [.saveDataDirectory(currentInput)])
            }
            if key == "\u{7F}" {
                var s = state
                s.settings = .editing(currentInput: String(currentInput.dropLast()))
                return (s, [])
            }
            // Printable ASCII guard: visible (>= 0x20), not DEL (0x7F),
            // not newline, not tab, not Esc.
            if key.isASCII,
               !key.isNewline,
               key != "\u{1B}",
               key != "\t",
               let ascii = key.asciiValue,
               ascii >= 0x20,
               ascii != 0x7F {
                var s = state
                s.settings = .editing(currentInput: currentInput + String(key))
                return (s, [])
            }
            return (state, [])
        }
    }
}

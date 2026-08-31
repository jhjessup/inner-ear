import Foundation
import InnerEarCore

/// Pure rendering logic for the TUI. Given a state and terminal dimensions,
/// returns an array of lines (one per row) ready to be written to the
/// terminal. No I/O, no side effects — fully testable.
///
/// The renderer produces a persistent multipane frame in the style of
/// nmtui / Midnight Commander: a nav pane on the left (showing the three
/// sections Record / Recordings / Settings) and a detail pane on the
/// right, surrounded by a box-drawn border with a top title bar and a
/// bottom key-legend footer.
public enum TUIRenderer {

    /// Width of the left nav pane in columns (between the left border and
    /// the vertical divider).
    static let navPaneWidth: Int = 22

    /// Minimum terminal size the multipane layout is willing to attempt.
    /// Below this we bail with a single-line message rather than try to
    /// cram the layout into something that would corrupt the screen.
    static let minWidth: Int = 60
    static let minHeight: Int = 18

    /// The pipeline always has exactly 3 phases (transcribe, diarize,
    /// summarize) — kept as a constant here rather than stored per-state,
    /// since it never varies.
    static let processingTotalSteps: Int = 3

    /// Render the current state to a line array bounded by `width` × `height`.
    ///
    /// - Parameters:
    ///   - state: The TUI state to render.
    ///   - width: Terminal width in columns (characters). Every returned
    ///     line is exactly `width` characters wide (padded with spaces,
    ///     truncated with no ellipsis — we never write past the right
    ///     border).
    ///   - height: Terminal height in rows. The returned array has exactly
    ///     `height` elements (or fewer, when the terminal is too small and
    ///     the minimum-size guard fires).
    /// - Returns: An array of strings, one per screen line, top to bottom.
    public static func render(state: TUIState, width: Int, height: Int) -> [String] {
        // Minimum-size guard: single-line message, no padding.
        if width < minWidth || height < minHeight {
            return ["Terminal too small (resize to at least \(minWidth)x\(minHeight))"]
        }

        // Fixed frame row indices (0-based, inclusive):
        //   0            top border
        //   1            title bar
        //   2            top divider (T-junction with vertical nav/detail divider)
        //   3 .. h-4     content rows (nav pane + detail pane side by side)
        //   h-3          bottom divider
        //   h-2          footer (key legend)
        //   h-1          bottom border
        let topBorderRow = 0
        let titleRow = 1
        let topDividerRow = 2
        let contentStart = 3
        let bottomDividerRow = height - 3
        let footerRow = height - 2
        let bottomBorderRow = height - 1

        // Column counts for the content rows.
        // The middle column is the vertical divider between nav and detail.
        //   columns 0         = left border "|"
        //   columns 1..navW   = nav pane
        //   column  navW+1    = vertical divider "|"
        //   columns ..width-1 = detail pane + right border "|"
        let navW = navPaneWidth
        let detailW = width - navW - 3   // = width - 1 (left border) - 1 (mid divider) - 1 (right border) - (navW - 1) ...

        // Pre-compute the detail content for the current section once; it
        // doesn't change per content row.
        let detailHeight = contentRowsAvailable(height: height)
        let detailLines = renderDetail(
            state: state,
            detailWidth: detailW,
            detailHeight: detailHeight
        )
        // Pad/truncate detailLines to exactly detailHeight rows.
        let detailRows: [String] = padRows(lines: detailLines, targetCount: detailHeight, width: detailW)

        // Build the frame row by row.
        var frame: [String] = Array(repeating: String(repeating: " ", count: width), count: height)

        // Row 0: top border.
        frame[topBorderRow] = makeTopBorder(width: width)

        // Row 1: title bar.
        frame[titleRow] = makeTitleRow(width: width)

        // Row 2: top divider (T-junction with vertical mid divider).
        frame[topDividerRow] = makeHorizontalDivider(width: width, navW: navW, bottomJunction: false)

        // Content rows.
        for r in contentStart..<(bottomDividerRow + 1) {
            let contentRowIndex = r - contentStart
            let navLine: String
            if contentRowIndex < 3 {
                navLine = renderNavRow(index: contentRowIndex, state: state)
            } else {
                navLine = ""
            }
            let detailLine = contentRowIndex < detailRows.count ? detailRows[contentRowIndex] : ""
            frame[r] = makeContentRow(navLine: navLine, detailLine: detailLine, navW: navW, totalWidth: width)
        }

        // Bottom divider (mirrors top).
        frame[bottomDividerRow] = makeHorizontalDivider(width: width, navW: navW, bottomJunction: true)

        // Footer.
        frame[footerRow] = makeFooterRow(state: state, width: width)

        // Bottom border.
        frame[bottomBorderRow] = makeBottomBorder(width: width)

        // Modal overlay (after the full frame is built; we slice/replace).
        if state.modal != nil {
            overlayModal(state: state, frame: &frame, width: width, height: height)
        }

        return frame
    }

    // MARK: - Nav pane

    /// Renders one row of the nav pane. The first 3 rows are the section
    /// names; the rest is left blank.
    ///
    /// Marker convention (shared with the Recordings list's row markers —
    /// see `selectionPrefix(isSelected:isFocused:)` — so "where the user's
    /// keyboard focus actually is" always looks the same regardless of
    /// which pane that happens to be):
    ///   `"> "` — this row has actual keyboard focus right now.
    ///   `"- "` — selected, but focus is currently on the other pane.
    ///   `"  "` — neither.
    /// (The nav pane previously used a bracket-wrapped `"[> Name ]"` for
    /// the focused case and a bare `"> Name"` for the selected-not-focused
    /// case — two different shapes for two different concepts, but the
    /// Recordings list only ever drew the bare arrow, so the SAME concept
    /// — "this is where you actually are" — looked different depending on
    /// which pane it was in. This unifies both to the 3-tier convention
    /// above.)
    private static func renderNavRow(index: Int, state: TUIState) -> String {
        guard index >= 0 && index < 3 else { return "" }
        let name = tuiSectionNames[index]
        let isSelected = index == state.selectedSection
        let isFocused = state.focusedPane == .navigation
        let prefix = selectionPrefix(isSelected: isSelected, isFocused: isFocused)
        return pad("\(prefix)\(name)", width: navPaneWidth)
    }

    /// Shared selection-marker prefix — see `renderNavRow`'s doc comment
    /// for why this must be identical wherever a "which row currently has
    /// keyboard focus" indicator is drawn.
    private static func selectionPrefix(isSelected: Bool, isFocused: Bool) -> String {
        guard isSelected else { return "  " }
        return isFocused ? "> " : "- "
    }

    // MARK: - Detail pane

    /// Compute the number of content rows available between the top
    /// divider (row 2) and the bottom divider (row height-3), inclusive of
    /// the bottom divider row. The actual fillable rows are
    /// (height - 4) - 3 + 1 = height - 6 rows. Wait: rows 3..height-4 are
    /// the content rows, so the count is (height - 4) - 3 + 1 = height - 6.
    static func contentRowsAvailable(height: Int) -> Int {
        // contentStart = 3, bottomDividerRow = height - 3, so the inclusive
        // content range is 3 .. (height - 4), giving (height - 4) - 3 + 1
        // = height - 6 rows.
        return max(1, height - 6)
    }

    /// Render the detail pane content for the current section as a list
    /// of lines (NOT yet padded/truncated to the width).
    private static func renderDetail(state: TUIState, detailWidth: Int, detailHeight: Int) -> [String] {
        switch state.selectedSection {
        case 0:
            return renderRecordDetail(state: state, width: detailWidth)
        case 1:
            return renderRecordingsDetail(state: state, width: detailWidth, height: detailHeight)
        case 2:
            return renderSettingsDetail(state: state, width: detailWidth)
        default:
            return []
        }
    }

    /// Section 0 (Record) detail lines.
    private static func renderRecordDetail(state: TUIState, width: Int) -> [String] {
        switch state.record {
        case .idle:
            // Both .idle and .prompting are reached via Enter, back to back,
            // with nothing else changing in between — a plain single line
            // here reads as no visible response to the first Enter at all.
            // A heading plus a blank separator line makes the transition
            // from "just entered this section" to "now on step 1" visually
            // distinct, and the footer (see footerText) spells out that
            // this Enter specifically starts a recording, not a generic
            // "[Enter] Confirm".
            return [
                "Record",
                "",
                "Press Enter to start a new recording."
            ]
        case .prompting:
            return [
                "New Recording",
                "",
                "Include system audio?",
                "",
                "[y] Yes, capture system audio too",
                "[n] No, microphone only"
            ]
        case .recording(let startedAt, let captureSystemAudio):
            // Same MM:SS elapsed computation as the old renderRecording
            // helper, plus the [s] Stop hint.
            let elapsed = Date().timeIntervalSince(startedAt)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            let timeStr = String(format: "%02d:%02d", minutes, seconds)
            let sysAudioStr = captureSystemAudio ? "on" : "off"
            return [
                "Recording... \(timeStr)  (system audio: \(sysAudioStr))",
                "",
                "[s] Stop"
            ]
        case .saved(let recording):
            return [
                "Recording saved: \(recording.id.uuidString)",
                "",
                "[Enter] Process now"
            ]
        }
    }

    /// Section 1 (Recordings) detail lines. Reuses the OLD `renderBrowsing`
    /// windowing/selection math, and the OLD `renderViewingResults`
    /// wrap-and-clamp math, but without the per-pane footer line.
    private static func renderRecordingsDetail(state: TUIState, width: Int, height: Int) -> [String] {
        switch state.recordings {
        case .list(let entries, let selectedIndex):
            return renderRecordingsList(
                entries: entries,
                selectedIndex: selectedIndex,
                width: width,
                height: height,
                isFocused: state.focusedPane == .detail
            )

        case .confirmGenerateTranscript(let entries, let selectedIndex):
            return renderConfirmGenerateTranscript(entries: entries, selectedIndex: selectedIndex, width: width)

        case .confirmDelete(let entries, let selectedIndex):
            return renderConfirmDelete(entries: entries, selectedIndex: selectedIndex, width: width)

        case .processing(let recording, let statusLine, let stepIndex):
            return [
                "Processing \(recording.title)...",
                statusLine,
                renderProgressBar(stepIndex: stepIndex, width: width),
                "Step \(min(stepIndex, processingTotalSteps)) of \(processingTotalSteps)"
            ]

        case .viewingResults(let transcript, let summary, let scrollOffset):
            return renderRecordingsResults(
                transcript: transcript,
                summary: summary,
                scrollOffset: scrollOffset,
                width: width,
                height: height
            )
        }
    }

    /// Replicates the OLD `renderBrowsing` logic (centered window around
    /// `selectedIndex`, no footer), plus an attribute bar below the list
    /// showing capture time + full file paths for the currently-selected
    /// row. The attribute bar reserves a fixed 4 rows (blank separator +
    /// 3 info lines) from the list's height budget, so the list's windowing
    /// math sees a smaller content height than the caller passed in.
    private static func renderRecordingsList(entries: [RecordingListEntry], selectedIndex: Int, width: Int, height: Int, isFocused: Bool) -> [String] {
        if entries.isEmpty {
            return ["No recordings yet."]
        }

        // Reserve 4 lines at the bottom of the content area for the
        // attribute bar (blank separator + Captured / Audio / Transcript).
        let attributeBarReserved = 4
        let listHeight = max(1, height - attributeBarReserved)

        let startIndex = max(0, min(selectedIndex - listHeight / 2, entries.count - listHeight))
        let endIndex = min(startIndex + listHeight, entries.count)

        var lines: [String] = []
        for i in startIndex..<endIndex {
            let entry = entries[i]
            let prefix = selectionPrefix(isSelected: i == selectedIndex, isFocused: isFocused)
            let marker = "[\(entry.hasAudio ? "A" : "-")\(entry.hasTranscript ? "T" : "-")]"
            // The title already embeds its own capture timestamp
            // ("Recording yyyy-MM-dd HH:mm:ss" — see AVFoundationAudioCaptureService),
            // so appending a SECOND, differently-formatted date/time here was
            // pure redundancy on an already-tight row. The last field is now
            // the recording's duration, plus a word count once it has a
            // transcript — information the title/marker don't already carry.
            let trailing = trailingSummary(for: entry)
            let line = "\(prefix)\(marker) \(entry.recording.title)  —  \(trailing)"
            lines.append(pad(line, width: width))
        }

        // Attribute bar — reflects `entries[selectedIndex]`. Reads the
        // current `selectedIndex` from the .list case's associated value
        // each render so it updates live as the user presses j/k. Always
        // shows (entries are guaranteed non-empty at this point).
        let selected = entries[selectedIndex]
        let captureFormatter = DateFormatter()
        captureFormatter.dateStyle = .medium
        captureFormatter.timeStyle = .medium
        let capturedStr = captureFormatter.string(from: selected.recording.createdAt)
        let audioPath = selected.recording.microphoneFileURL.path
        let audioExtra = selected.recording.systemAudioFileURL != nil ? " (+ system audio)" : ""
        let transcriptPath = selected.transcriptFileURL?.path ?? "— not yet generated —"
        let audioLabel = selected.hasAudio ? "\(audioPath)\(audioExtra)" : "— not present —"

        lines.append("") // blank separator between list and attribute bar
        lines.append(pad("Captured: \(capturedStr)", width: width))
        lines.append(pad("Audio: \(audioLabel)", width: width))
        lines.append(pad("Transcript: \(transcriptPath)", width: width))

        return lines
    }

    /// `.confirmGenerateTranscript` — single-question confirm dialog.
    private static func renderConfirmGenerateTranscript(entries: [RecordingListEntry], selectedIndex: Int, width: Int) -> [String] {
        let title = entries[selectedIndex].recording.title
        return [
            "\"\(title)\" has no transcript yet.",
            "",
            "Generate one now? [y/n]"
        ].map { pad($0, width: width) }
    }

    /// `.confirmDelete` — sub-menu for choosing which artifact(s) to delete.
    private static func renderConfirmDelete(entries: [RecordingListEntry], selectedIndex: Int, width: Int) -> [String] {
        let title = entries[selectedIndex].recording.title
        return [
            "Delete for \"\(title)\":",
            "",
            "[a] Audio only   [t] Transcript only   [b] Both   [Esc] Cancel"
        ].map { pad($0, width: width) }
    }

    /// Replicates the OLD `renderViewingResults` wrap + scroll-clamp math
    /// exactly, but without its per-pane footer (the global footer at the
    /// bottom of the frame now serves that role).
    ///
    /// Segments are grouped into speaker TURNS before rendering: WhisperKit
    /// commonly splits one sentence into several short segments, which —
    /// rendered one-tag-per-segment — produced a wall of near-duplicate
    /// "[00:00]"/"[00:02]"/"[00:03]" tags for what was really one person
    /// talking continuously. Consecutive segments sharing the same
    /// `speakerID` are merged into a single paragraph carrying only the
    /// FIRST segment's timestamp (a turn's start, not a running tag per
    /// sentence fragment). This is purely a display grouping — the
    /// underlying `Transcript.segments` array (and everything exported to
    /// file) is completely unchanged; only how this one view presents them
    /// is different.
    private static func renderRecordingsResults(
        transcript: Transcript,
        summary: Summary?,
        scrollOffset: Int,
        width: Int,
        height: Int
    ) -> [String] {
        let paragraphs = groupedSpeakerTurnParagraphs(for: transcript)
        var fullText = paragraphs.joined(separator: "\n\n")

        if let summary = summary {
            fullText += "\n\n--- Summary ---\n"
            fullText += summary.overview + "\n"
            if !summary.keyPoints.isEmpty {
                fullText += "\nKey Points:\n"
                for point in summary.keyPoints {
                    fullText += "- \(point)\n"
                }
            }
            if !summary.decisions.isEmpty {
                fullText += "\nDecisions:\n"
                for decision in summary.decisions {
                    fullText += "- \(decision)\n"
                }
            }
            if !summary.actionItems.isEmpty {
                fullText += "\nAction Items:\n"
                for item in summary.actionItems {
                    fullText += "- \(item.text)\n"
                }
            }
        }

        // Split into lines and wrap at `width`.
        var allLines: [String] = []
        for paragraph in fullText.split(separator: "\n", omittingEmptySubsequences: false) {
            let para = String(paragraph)
            if para.isEmpty {
                allLines.append("")
            } else {
                // Simple word-wrapping by width (not word-boundary-aware for v1).
                var remaining = para
                while !remaining.isEmpty {
                    let chunk = String(remaining.prefix(width))
                    allLines.append(chunk)
                    remaining = String(remaining.dropFirst(chunk.count))
                }
            }
        }

        // No footer reserved; the whole content area is available.
        let visibleHeight = max(1, height)
        let clampedOffset = min(scrollOffset, max(0, allLines.count - visibleHeight))
        let start = clampedOffset
        let end = min(start + visibleHeight, allLines.count)

        // If the content is short, return only the content lines (don't pad
        // to height). The caller will pad empty rows around it to fill the
        // detail pane's available rows.
        if allLines.count <= visibleHeight {
            return allLines.map { pad($0, width: width) }
        }
        return Array(allLines[start..<end]).map { pad($0, width: width) }
    }

    /// Format a segment's `startTime` (seconds, possibly fractional) as
    /// MM:SS for display in the per-segment transcript viewer header.
    /// Distinct from the recording-elapsed-time formatter in
    /// `renderRecordDetail` because the inputs come from different sources
    /// (segment start offset vs. wall-clock `Date`-subtraction elapsed),
    /// even though they share the same output format.
    private static func formatSegmentTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Merge consecutive same-speaker segments into one "[MM:SS] Speaker:"
    /// paragraph per turn (see `renderRecordingsResults`'s doc comment for
    /// why). Segments are assumed already in chronological order (true for
    /// both the plain WhisperKitTranscriptionService output and
    /// ChannelBasedDiarizationService's merged/sorted result) — this only
    /// groups adjacent runs, it does not reorder anything.
    private static func groupedSpeakerTurnParagraphs(for transcript: Transcript) -> [String] {
        struct Turn {
            let speakerID: UUID?
            let startTime: TimeInterval
            var texts: [String]
        }

        var turns: [Turn] = []
        for segment in transcript.segments {
            if let last = turns.last, last.speakerID == segment.speakerID {
                turns[turns.count - 1].texts.append(segment.text)
            } else {
                turns.append(Turn(speakerID: segment.speakerID, startTime: segment.startTime, texts: [segment.text]))
            }
        }

        return turns.map { turn in
            let speakerLabel = transcript.speakers.first { $0.id == turn.speakerID }?.label ?? "Unknown"
            let timestamp = formatSegmentTime(turn.startTime)
            let text = turn.texts.joined(separator: " ")
            return "[\(timestamp)] \(speakerLabel): \(text)"
        }
    }

    /// The last field on a Recordings-list row: the recording's duration,
    /// plus a word count once a transcript exists. Replaces a second,
    /// redundant date/time stamp (the title already has one).
    private static func trailingSummary(for entry: RecordingListEntry) -> String {
        let duration = formatSegmentTime(entry.recording.duration)
        guard let transcript = entry.transcript else {
            return duration
        }
        let wordCount = transcript.fullText.split(separator: " ").count
        return "\(duration), \(wordCount) words"
    }

    /// Render a discrete (not animated) progress bar for the processing
    /// pipeline: `stepIndex` filled out of `processingTotalSteps` total.
    ///
    /// This is deliberately NOT a smoothly-animating bar. The run loop
    /// blocks synchronously on each pipeline phase's `await` (no concurrent
    /// Tasks, by design — see TUIRunLoop's doc comment on why) and only
    /// calls `render` again once a phase completes, so anything meant to
    /// animate *during* a phase would need a background redraw Task and
    /// would sit visibly frozen the instant that Task wasn't actually
    /// running, which is worse than no animation at all. What CAN be shown
    /// honestly is which of the 3 known phases has started — real,
    /// non-fabricated progress — updated at each of the render calls that
    /// already happen when a phase begins.
    private static func renderProgressBar(stepIndex: Int, width: Int) -> String {
        let clampedStep = min(max(stepIndex, 0), processingTotalSteps)
        let barWidth = max(10, min(40, width - 2))
        let filled = Int((Double(clampedStep) / Double(processingTotalSteps) * Double(barWidth)).rounded())
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barWidth - filled)
        return "[\(bar)]"
    }

    /// Section 2 (Settings) detail lines.
    private static func renderSettingsDetail(state: TUIState, width: Int) -> [String] {
        switch state.settings {
        case .viewing(let resolvedPath, let source):
            return [
                "Data directory:",
                "  \(resolvedPath)",
                "",
                "Source: \(sourceDescription(source))",
                "",
                "[e] Edit"
            ]
        case .editing(let currentInput):
            return [
                "Enter new data directory path:",
                "",
                "> \(currentInput)_"
            ]
        }
    }

    /// Human-readable description of a `DataDirectorySource`.
    private static func sourceDescription(_ source: DataDirectorySource) -> String {
        switch source {
        case .envVar:        return "INNEREAR_DATA_DIR environment variable"
        case .configFile:    return "config.json"
        case .defaultLocation: return "default (Application Support)"
        }
    }

    // MARK: - Footer

    /// Build the footer key-legend text for the current state.
    static func footerText(for state: TUIState) -> String {
        // Modal wins first.
        if state.modal != nil {
            return "[Enter/Esc] Dismiss"
        }
        // Recording active (locked state).
        if case .recording = state.record {
            return "[s]/[Esc] Stop"
        }
        // Nav-pane focused.
        if state.focusedPane == .navigation {
            return "[j/k] Select  [->/Enter] Open  [Tab] Detail  [q] Quit"
        }
        // Detail-pane focused: dispatch on section.
        switch state.selectedSection {
        case 0:
            switch state.record {
            case .idle:
                return "[Enter] Start Recording  [Tab] Nav  [Esc] Back"
            case .prompting:
                // Enter does nothing here — y/n do — so don't advertise it.
                return "[y] Yes  [n] No  [Esc] Cancel"
            case .saved:
                return "[Enter] Process Now  [Tab] Nav  [Esc] Back"
            case .recording:
                // Already covered above, but defensive.
                return "[s]/[Esc] Stop"
            }
        case 1:
            switch state.recordings {
            case .list:
                return "[j/k] Move  [Enter] Select  [d] Delete  [Tab] Nav  [Esc] Back"
            case .confirmGenerateTranscript:
                return "[y] Generate  [n]/[Esc] Cancel"
            case .confirmDelete:
                return "[a] Audio  [t] Transcript  [b] Both  [Esc] Cancel"
            case .viewingResults:
                return "[j/k] Line  [space/b] Page  [g/G] Top/Bottom  [e] Export  [<-] Nav  [Esc] Back"
            case .processing:
                return "[Tab] Nav"
            }
        case 2:
            switch state.settings {
            case .viewing:
                return "[e] Edit  [Tab] Nav  [Esc] Back"
            case .editing:
                return "[Enter] Save  [Esc] Cancel  [Backspace] Delete"
            }
        default:
            return "[Tab] Nav"
        }
    }

    // MARK: - Modal overlay

    /// Overwrite a centered rectangular region of the already-built frame
    /// with a bordered box containing the modal's contents. Only the
    /// `.error(String)` case exists today, but the layout is generic
    /// enough to accommodate additional modal kinds in the future.
    private static func overlayModal(state: TUIState, frame: inout [String], width: Int, height: Int) {
        guard case .error(let message) = state.modal else { return }

        // Box dimensions: width = min(60, width-4), height = 5, centered.
        let boxW = min(60, max(10, width - 4))
        let boxH = 5
        let leftCol = max(0, (width - boxW) / 2)
        let topRow = max(0, (height - boxH) / 2)

        // Wrap the message to fit (boxW - 2) columns, leaving 1 col on each
        // side for the border.
        let innerW = max(1, boxW - 2)
        let wrapped = wrapMessage(message, width: innerW)
        let footer = "[Enter/Esc] Dismiss"

        // Box rows (top to bottom):
        //   0: top border
        //   1: inner with message (truncated to innerW; pad)
        //   2: empty inner row (or second message line if it fits)
        //   3: inner with footer
        //   4: bottom border
        let topBorder = "┌" + String(repeating: "─", count: boxW - 2) + "┐"
        let bottomBorder = "└" + String(repeating: "─", count: boxW - 2) + "┘"
        let line0 = "│" + pad(wrapped[0], width: innerW) + "│"
        let line1: String
        if wrapped.count >= 2 {
            line1 = "│" + pad(wrapped[1], width: innerW) + "│"
        } else {
            line1 = "│" + pad("", width: innerW) + "│"
        }
        let line2 = "│" + pad(footer, width: innerW) + "│"

        let boxRows = [topBorder, line0, line1, line2, bottomBorder]

        // Splice each box row into the frame at (topRow + i, leftCol).
        for (i, row) in boxRows.enumerated() {
            let r = topRow + i
            guard r >= 0, r < height else { continue }
            // Replace columns [leftCol, leftCol + boxW) of frame[r] with row.
            // Every frame row is already exactly `width` characters wide, so
            // string slicing + concatenation is safe.
            let leftPad = String(frame[r].prefix(leftCol))
            let rightStart = leftCol + boxW
            let rightPad = rightStart < width ? String(frame[r].suffix(width - rightStart)) : ""
            frame[r] = leftPad + row + rightPad
        }
    }

    /// Trivial character-wrapping for modal messages. Splits at newlines
    /// first, then hard-wraps any segment longer than `width`. Good enough
    /// for v1 error messages.
    private static func wrapMessage(_ message: String, width: Int) -> [String] {
        var out: [String] = []
        for paragraph in message.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(paragraph)
            if s.isEmpty {
                out.append("")
                continue
            }
            var remaining = s
            while !remaining.isEmpty {
                out.append(String(remaining.prefix(width)))
                remaining = String(remaining.dropFirst(min(width, remaining.count)))
            }
        }
        if out.isEmpty { out = [""] }
        return out
    }

    // MARK: - Frame builders (private)

    private static func makeTopBorder(width: Int) -> String {
        "┌" + String(repeating: "─", count: width - 2) + "┐"
    }

    private static func makeBottomBorder(width: Int) -> String {
        "└" + String(repeating: "─", count: width - 2) + "┘"
    }

    private static func makeTitleRow(width: Int) -> String {
        let content = " InnerEar "
        let inner = max(0, width - 2)
        if content.count >= inner {
            return "│" + String(content.prefix(inner)) + "│"
        }
        let leftPad = (inner - content.count) / 2
        let rightPad = inner - content.count - leftPad
        return "│" + String(repeating: "─", count: leftPad) + content + String(repeating: "─", count: rightPad) + "│"
    }

    /// Row 2 (or the bottom divider): "├" + "─"×navW + "┬"/"┴" + "─"×rest + "┤".
    private static func makeHorizontalDivider(width: Int, navW: Int, bottomJunction: Bool) -> String {
        let midJunction = bottomJunction ? "┴" : "┬"
        let rightCount = max(0, width - navW - 3)
        return "├" + String(repeating: "─", count: navW) + midJunction + String(repeating: "─", count: rightCount) + "┤"
    }

    /// Build a content row: "│" + navLine(padded) + "│" + detailLine(padded) + "│".
    private static func makeContentRow(navLine: String, detailLine: String, navW: Int, totalWidth: Int) -> String {
        let detailW = totalWidth - navW - 3
        return "│" + pad(navLine, width: navW) + "│" + pad(detailLine, width: detailW) + "│"
    }

    private static func makeFooterRow(state: TUIState, width: Int) -> String {
        "│" + pad(footerText(for: state), width: width - 2) + "│"
    }

    // MARK: - Helpers (private)

    /// Pad `s` with trailing spaces to exactly `width` characters,
    /// truncating from the right if it's too long. We never append an
    /// ellipsis here — we just chop, because the caller always wants a
    /// line of exactly `width` characters and ellipses would mess up the
    /// box border alignment.
    private static func pad(_ s: String, width: Int) -> String {
        if width <= 0 { return "" }
        if s.count == width { return s }
        if s.count > width { return String(s.prefix(width)) }
        return s + String(repeating: " ", count: width - s.count)
    }

    /// Pad/truncate an array of lines so it has exactly `targetCount`
    /// entries, each of exactly `width` characters.
    private static func padRows(lines: [String], targetCount: Int, width: Int) -> [String] {
        var out: [String] = []
        out.reserveCapacity(targetCount)
        for i in 0..<targetCount {
            if i < lines.count {
                out.append(pad(lines[i], width: width))
            } else {
                out.append(String(repeating: " ", count: width))
            }
        }
        return out
    }
}

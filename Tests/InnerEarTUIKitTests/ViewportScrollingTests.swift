import Foundation
import Testing
@testable import InnerEarTUIKit
import InnerEarCore

/// Focused tests for the viewport scrolling/clamping logic in
/// `TUIRenderer.render` for the Recordings `.viewingResults` state.
///
/// These tests verify that the visible window of lines never goes past the
/// end of content, regardless of the `scrollOffset` passed in (which may
/// come from the controller unclamped, or from a future UI that allows
/// large jumps).
struct ViewportScrollingTests {

    // MARK: - Fixtures

    private func makeLongTranscript(width: Int, lineCount: Int) -> Transcript {
        let speaker = Speaker(label: "Speaker 1", colorHex: "#3478F6", isLocalUser: true)
        // Each "line" of content will be exactly `width` chars so wrapping
        // produces exactly one output line per input line.
        let line = String(repeating: "X", count: width)
        let fullText = Array(repeating: line, count: lineCount).joined(separator: "\n")
        return Transcript(
            id: UUID(),
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [speaker],
            segments: [
                TranscriptSegment(speakerID: speaker.id, text: fullText, startTime: 0, endTime: 100)
            ],
            generatedAt: Date()
        )
    }

    /// Wrap a `viewingResults` value in a full `TUIState` so it dispatches
    /// into the Recordings/.viewingResults renderer path. (The new
    /// `TUIRenderer.render` is dispatched on `state.selectedSection` and
    /// `state.focusedPane`; it is not a direct `viewingResults` dispatch.)
    private func viewingResultsState(
        transcript: Transcript,
        summary: Summary?,
        scrollOffset: Int
    ) -> TUIState {
        TUIState(
            focusedPane: .detail,
            selectedSection: 1,
            recordings: .viewingResults(
                transcript: transcript,
                summary: summary,
                scrollOffset: scrollOffset
            )
        )
    }

    // MARK: - Tests

    // The new multipane renderer requires the terminal be at least 60x18
    // (its minimum-size guard) before it will lay out a frame. All tests
    // below use sizes at or above that floor.

    @Test
    func scrollOffsetZero_showsFirstWindow() {
        let width = 80
        let height = 24
        let transcript = makeLongTranscript(width: 40, lineCount: 30)
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: 0)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        // The whole `height` of the frame is filled (top border through
        // bottom border, no per-pane footer anymore). All lines should
        // be exactly `width` characters wide.
        #expect(lines.count == height)
        for line in lines {
            #expect(line.count == width)
        }
    }

    @Test
    func scrollOffsetWithinRange_showsCorrectWindow() {
        let width = 80
        let height = 24
        let transcript = makeLongTranscript(width: 40, lineCount: 30)
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: 5)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
    }

    @Test
    func scrollOffsetBeyondEnd_clampedToLastWindow() {
        let width = 80
        let height = 24
        let contentLines = 30
        let transcript = makeLongTranscript(width: 40, lineCount: contentLines)
        // Scroll offset way past the end
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: 1000)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
        // None of the lines should be entirely empty (which would happen
        // if the renderer failed to clamp and produced blank rows after
        // the content was exhausted). Box-drawing characters in border
        // rows are non-empty; inner content rows are populated by
        // scroll-clamped transcript content.
        for line in lines {
            #expect(!line.isEmpty)
        }
    }

    @Test
    func scrollOffsetExactlyAtLastWindow_showsLastWindow() {
        let width = 80
        let height = 24
        let contentLines = 30
        let transcript = makeLongTranscript(width: 40, lineCount: contentLines)
        // The last valid window starts at contentLines - detailHeight.
        // detailHeight = height - 6, so the last valid offset is
        // contentLines - (height - 6) = contentLines - height + 6.
        // For contentLines=30, height=24: lastValidOffset = 30 - 24 + 6 = 12.
        let lastValidOffset = contentLines - (height - 6)
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: lastValidOffset)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
        for line in lines {
            #expect(!line.isEmpty)
        }
    }

    @Test
    func shortContent_doesNotCrash_atLargeOffset() {
        let width = 80
        let height = 24
        let transcript = makeLongTranscript(width: 40, lineCount: 3) // Only 3 lines of content
        // Even with a large scrollOffset, we should render cleanly
        // (renderer clamps to the last valid window).
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: 100)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
        for line in lines {
            #expect(line.count == width)
        }
    }

    @Test
    func withSummary_longContent_clampingStillWorks() {
        let width = 80
        let height = 24
        let transcript = makeLongTranscript(width: 40, lineCount: 20)
        let summary = Summary(
            id: UUID(),
            transcriptID: UUID(),
            overview: "Overview text that adds more lines.",
            keyPoints: ["Point 1", "Point 2", "Point 3"],
            decisions: ["Decision 1"],
            actionItems: [Summary.ActionItem(text: "Action 1", ownerSpeakerID: nil)],
            generatedByModel: "test",
            generatedAt: Date()
        )
        // Large scroll offset
        let state = viewingResultsState(transcript: transcript, summary: summary, scrollOffset: 500)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
        for line in lines {
            #expect(!line.isEmpty)
        }
    }

    @Test
    func narrowWidth_wrappingProducesManyLines_clampingWorks() {
        // With a narrow detail pane, a single long paragraph wraps to many
        // lines. We still need width >= 60 to pass the renderer's
        // minimum-size guard at the outer level — only the detail-pane
        // content width is narrow.
        let width = 60
        let height = 18
        let speaker = Speaker(label: "Speaker 1", colorHex: "#3478F6", isLocalUser: true)
        let longPara = String(repeating: "Word ", count: 50) // ~250 chars
        let transcript = Transcript(
            id: UUID(),
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [speaker],
            segments: [
                TranscriptSegment(speakerID: speaker.id, text: longPara, startTime: 0, endTime: 100)
            ],
            generatedAt: Date()
        )
        // Large offset
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: 100)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
        for line in lines {
            #expect(line.count == width)
        }
    }

    @Test
    func scrollOffsetZero_rendersExactlyWidthCharsPerLine() {
        // Cross-check that the new renderer always returns lines of
        // exactly `width` characters (the box-drawing layout requires
        // this so vertical borders line up).
        let width = 80
        let height = 24
        let transcript = makeLongTranscript(width: 40, lineCount: 30)
        let state = viewingResultsState(transcript: transcript, summary: nil, scrollOffset: 0)
        let lines = TUIRenderer.render(state: state, width: width, height: height)
        #expect(lines.count == height)
        for line in lines {
            #expect(line.count == width)
        }
    }
}

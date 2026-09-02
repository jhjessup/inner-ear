import Foundation
import Testing
@testable import InnerEarCore

/// Tests for `WhisperKitTranscriptionService.sanitizeSegmentText`, the pure
/// string-cleanup helper that strips WhisperKit/Whisper `<|...|>`
/// special-token markup out of segment text before it reaches the domain
/// model. No real WhisperKit pipeline, Core ML, or audio involved — see
/// TEST_DOCTRINE.md AX-P2 ("No Real Audio/Model Execution in Unit Tests").
struct WhisperKitTranscriptionServiceTests {

    @Test
    func sanitizeSegmentText_plainText_isUnchanged() {
        let result = WhisperKitTranscriptionService.sanitizeSegmentText("hello there, how's it going")
        #expect(result == "hello there, how's it going")
    }

    @Test
    func sanitizeSegmentText_stripsLeadingLanguageAndControlTokens() {
        let raw = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|> hello there"
        #expect(WhisperKitTranscriptionService.sanitizeSegmentText(raw) == "hello there")
    }

    @Test
    func sanitizeSegmentText_stripsTrailingEndOfTextToken() {
        let raw = "hello there<|endoftext|>"
        #expect(WhisperKitTranscriptionService.sanitizeSegmentText(raw) == "hello there")
    }

    @Test
    func sanitizeSegmentText_stripsInlineWordTimestampTokens() {
        let raw = "<|0.00|> hello<|0.24|> there<|0.68|> how's<|0.91|> it<|1.10|> going<|1.42|>"
        #expect(WhisperKitTranscriptionService.sanitizeSegmentText(raw) == "hello there how's it going")
    }

    @Test
    func sanitizeSegmentText_collapsesWhitespaceLeftByTokenRemoval() {
        let raw = "hello   <|0.24|>   there"
        #expect(WhisperKitTranscriptionService.sanitizeSegmentText(raw) == "hello there")
    }

    @Test
    func sanitizeSegmentText_emptyInput_returnsEmpty() {
        #expect(WhisperKitTranscriptionService.sanitizeSegmentText("") == "")
    }

    @Test
    func sanitizeSegmentText_onlyTokens_returnsEmpty() {
        #expect(WhisperKitTranscriptionService.sanitizeSegmentText("<|startoftranscript|><|en|><|endoftext|>") == "")
    }
}

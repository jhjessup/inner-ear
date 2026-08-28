import Foundation
import Testing
@testable import InnerEarCore

/// Tests for the concrete `ExtractiveSummarizationService` implementation
/// (Phase 5 — extractive summarization, no ML, no network).
///
/// Uses Swift Testing (`@Test` / `#expect`) per TEST_DOCTRINE.md and the
/// pattern established in `ChannelBasedDiarizationServiceTests.swift`.
/// No real audio hardware, Core ML, or network — the implementation is
/// purely algorithmic and has no external dependencies.
struct ExtractiveSummarizationServiceTests {

    // MARK: - Helpers

    /// Build a multi-segment transcript with distinct topics and repeated
    /// key nouns ("budget", "deadline", "design") so frequency scoring is
    /// meaningful. Segments alternate between two speakers.
    private func makeMultiTopicTranscript() -> Transcript {
        let alice = TestFixtures.speaker(label: "Alice", isLocalUser: true)
        let bob = TestFixtures.speaker(label: "Bob", isLocalUser: false)

        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [alice, bob],
            segments: [
                // Segment 0: budget talk (high "budget" frequency)
                TranscriptSegment(
                    speakerID: alice.id,
                    text: "The budget for Q4 needs to be finalized by Friday.",
                    startTime: 0.0, endTime: 3.0
                ),
                // Segment 1: design talk (high "design" frequency)
                TranscriptSegment(
                    speakerID: bob.id,
                    text: "The new design system will unify our components.",
                    startTime: 4.0, endTime: 7.0
                ),
                // Segment 2: budget again (reinforces "budget" frequency)
                TranscriptSegment(
                    speakerID: alice.id,
                    text: "We have a tight budget so we must prioritize carefully.",
                    startTime: 8.0, endTime: 11.0
                ),
                // Segment 3: deadline talk (high "deadline" frequency)
                TranscriptSegment(
                    speakerID: bob.id,
                    text: "The deadline is non-negotiable — ship by end of month.",
                    startTime: 12.0, endTime: 15.0
                ),
                // Segment 4: design again (reinforces "design")
                TranscriptSegment(
                    speakerID: alice.id,
                    text: "Design reviews are scheduled for Tuesday and Thursday.",
                    startTime: 16.0, endTime: 19.0
                ),
                // Segment 5: mixed, lower salience
                TranscriptSegment(
                    speakerID: bob.id,
                    text: "Let me know if you have any questions about the timeline.",
                    startTime: 20.0, endTime: 22.0
                ),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    /// Build a transcript containing a decision phrase.
    private func makeDecisionTranscript() -> Transcript {
        let alice = TestFixtures.speaker(label: "Alice", isLocalUser: true)
        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [alice],
            segments: [
                TranscriptSegment(speakerID: alice.id, text: "Welcome everyone.", startTime: 0, endTime: 1),
                TranscriptSegment(speakerID: alice.id, text: "We decided to ship on Friday.", startTime: 2, endTime: 4),
                TranscriptSegment(speakerID: alice.id, text: "Meeting adjourned.", startTime: 5, endTime: 6),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    /// Build a transcript containing an action item phrase.
    private func makeActionItemTranscript() -> Transcript {
        let bob = TestFixtures.speaker(label: "Bob", isLocalUser: false)
        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [bob],
            segments: [
                TranscriptSegment(speakerID: bob.id, text: "Thanks for the update.", startTime: 0, endTime: 1),
                TranscriptSegment(speakerID: bob.id, text: "Action item: send the report to Alice by EOD.", startTime: 2, endTime: 5),
                TranscriptSegment(speakerID: bob.id, text: "See you tomorrow.", startTime: 6, endTime: 7),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    /// Build a transcript for chat testing — distinct keyword per segment.
    private func makeChatTranscript() -> Transcript {
        let alice = TestFixtures.speaker(label: "Alice", isLocalUser: true)
        let bob = TestFixtures.speaker(label: "Bob", isLocalUser: false)
        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [alice, bob],
            segments: [
                TranscriptSegment(speakerID: alice.id, text: "The budget approval process starts Monday.", startTime: 0, endTime: 3),
                TranscriptSegment(speakerID: bob.id, text: "Design system rollout is scheduled for June.", startTime: 4, endTime: 7),
                TranscriptSegment(speakerID: alice.id, text: "Deadline extensions require VP sign-off.", startTime: 8, endTime: 11),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    // MARK: - Tests

    @Test
    func summarize_emptySegments_throwsEmptyTranscript() async throws {
        let service = ExtractiveSummarizationService()
        let emptyTranscript = Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: "test",
            speakers: [],
            segments: [],
            generatedAt: Date()
        )

        await #expect(throws: SummarizationError.emptyTranscript) {
            try await service.summarize(transcript: emptyTranscript)
        }
    }

    @Test
    func summarize_multiTopicTranscript_keyPointsNonEmptyAndChronological() async throws {
        let service = ExtractiveSummarizationService()
        let transcript = makeMultiTopicTranscript()

        let summary = try await service.summarize(transcript: transcript)

        // keyPoints should be non-empty (up to 5)
        #expect(!summary.keyPoints.isEmpty)
        #expect(summary.keyPoints.count <= 5)

        // keyPoints must preserve chronological order — verify by
        // cross-referencing startTime against the original transcript's segments.
        let originalStartTimes = transcript.segments.map(\.startTime)
        let keyPointStartTimes = summary.keyPoints.compactMap { keyPointText -> TimeInterval? in
            transcript.segments.first { $0.text == keyPointText }?.startTime
        }
        #expect(keyPointStartTimes == keyPointStartTimes.sorted(),
                "keyPoints must appear in chronological order (ascending startTime)")

        // overview should be non-empty and composed of top segments
        #expect(!summary.overview.isEmpty)

        // generatedByModel should be the extractive model name
        #expect(summary.generatedByModel == "extractive-v1")

        // transcriptID should match
        #expect(summary.transcriptID == transcript.id)
    }

    @Test
    func summarize_decisionPhraseProducesDecisionsArray() async throws {
        let service = ExtractiveSummarizationService()
        let transcript = makeDecisionTranscript()

        let summary = try await service.summarize(transcript: transcript)

        #expect(!summary.decisions.isEmpty)
        // The decision segment text should appear verbatim
        #expect(summary.decisions.contains { $0.contains("We decided to ship on Friday") })
    }

    @Test
    func summarize_actionItemPhraseProducesActionItemsArray() async throws {
        let service = ExtractiveSummarizationService()
        let transcript = makeActionItemTranscript()

        let summary = try await service.summarize(transcript: transcript)

        #expect(!summary.actionItems.isEmpty)
        let actionText = summary.actionItems.first?.text ?? ""
        #expect(actionText.contains("Action item: send the report to Alice by EOD"))
        // ownerSpeakerID should be set to the segment's speaker
        #expect(summary.actionItems.first?.ownerSpeakerID == transcript.segments[1].speakerID)
    }

    @Test
    func chat_keywordOverlapReturnsMatchingSegment() async throws {
        let service = ExtractiveSummarizationService()
        let transcript = makeChatTranscript()

        // Question shares keywords with segment 0 ("budget", "approval", "process", "Monday")
        let answer = try await service.chat(transcript: transcript, question: "When does the budget approval happen?")

        #expect(answer.hasPrefix("Based on the transcript:"))
        #expect(answer.contains("budget approval process starts Monday"))
    }

    @Test
    func chat_noKeywordOverlapReturnsNotFoundMessage() async throws {
        let service = ExtractiveSummarizationService()
        let transcript = makeChatTranscript()

        // Question shares no keywords with any segment
        let answer = try await service.chat(transcript: transcript, question: "What is the weather like on Mars?")

        #expect(answer == "I couldn't find anything in the transcript matching your question.")
    }

    @Test
    func chat_multipleMatchingSegmentsReturnedChronologically() async throws {
        let service = ExtractiveSummarizationService()
        let transcript = makeChatTranscript()

        // "design" appears in segment 1, "deadline" in segment 2 — both match
        let answer = try await service.chat(transcript: transcript, question: "Tell me about design and deadline")

        #expect(answer.hasPrefix("Based on the transcript:"))
        // Both matching segments should appear, in chronological order
        #expect(answer.contains("Design system rollout is scheduled for June"))
        #expect(answer.contains("Deadline extensions require VP sign-off"))
        // Chronological: segment 1 (design) then segment 2 (deadline)
        let designRange = answer.range(of: "Design system rollout")!
        let deadlineRange = answer.range(of: "Deadline extensions")!
        #expect(designRange.lowerBound < deadlineRange.lowerBound)
    }

    @Test
    func backend_isLocalExtractiveV1() {
        let service = ExtractiveSummarizationService()
        #expect(service.backend == .local(modelName: "extractive-v1"))
    }
}
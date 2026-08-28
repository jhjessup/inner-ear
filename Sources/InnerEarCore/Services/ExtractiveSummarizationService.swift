import Foundation

/// A purely extractive summarization implementation — it selects and
/// repurposes actual words/sentences from the transcript rather than
/// generating new text. No local LLM, no network calls, no fabricated
/// "AI" behavior.
///
/// Scoring rationale:
/// - Each `TranscriptSegment` is treated as one scoring unit (segments
///   already represent natural utterance chunks from STT).
/// - Word frequencies are computed across ALL segments after lowercasing
///   and stripping punctuation, excluding a hardcoded English stopword list.
/// - Segment score = sum of its non-stopword token frequencies, normalized
///   by the segment's non-stopword token count. This prevents longer
///   segments from dominating purely due to length — we want density of
///   salient terms, not raw volume.
/// - Top N segments by score are selected (N = min(5, segment count)),
///   but output in their ORIGINAL chronological order so the summary reads
///   naturally in context.
public final class ExtractiveSummarizationService: SummarizationService, @unchecked Sendable {

    public init() {}

    public let backend: SummarizationBackend = .local(modelName: "extractive-v1")

    // MARK: - Stopwords & Phrase Patterns

    /// A reasonably comprehensive English stopword list for extractive
    /// scoring. Not exhaustive — just enough to suppress the most common
    /// function words that would otherwise drown out content words.
    private static let stopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "and", "or", "but",
        "to", "of", "in", "on", "at", "for", "with", "this", "that", "it",
        "i", "you", "we", "they", "he", "she", "be", "have", "has", "had",
        "do", "does", "did", "not", "so", "if", "as", "by", "from", "will",
        "would", "can", "could", "um", "uh", "my", "your", "our", "their",
        "his", "her", "its", "me", "him", "us", "them", "am", "been",
        "being", "was", "were", "has", "have", "had", "do", "does", "did",
        "shall", "should", "may", "might", "must", "ought", "need", "dare",
        "used", "use", "using", "also", "just", "like", "well", "then",
        "than", "very", "much", "many", "more", "most", "some", "any",
        "all", "each", "every", "other", "another", "such", "only", "own",
        "same", "so", "too", "even", "still", "yet", "already", "ever",
        "never", "now", "then", "here", "there", "when", "where", "why",
        "how", "what", "which", "who", "whom", "whose", "that", "these",
        "those", "this", "those", "them", "then", "than", "now", "here",
        "there", "up", "down", "out", "off", "over", "under", "again",
        "further", "once", "twice", "first", "second", "last", "next",
        "previous", "new", "old", "good", "bad", "big", "small", "long",
        "short", "high", "low", "early", "late", "right", "wrong", "true",
        "false", "yes", "no", "maybe", "okay", "ok", "sure", "thanks",
        "thank", "please", "sorry", "excuse", "pardon", "hello", "hi",
        "bye", "goodbye", "see", "look", "listen", "hear", "watch", "wait",
        "go", "come", "get", "give", "take", "make", "let", "put", "set",
        "keep", "hold", "bring", "send", "show", "tell", "ask", "answer",
        "say", "speak", "talk", "think", "know", "understand", "mean",
        "want", "need", "like", "love", "hate", "hope", "wish", "expect",
        "seem", "appear", "look", "sound", "feel", "taste", "smell"
    ]

    /// Phrases that strongly indicate a decision was made. Case-insensitive
    /// substring match on the segment text.
    private static let decisionPhrases = [
        "we decided", "we'll go with", "we agreed", "the decision is",
        "let's go with", "we're going to", "i've decided", "i have decided"
    ]

    /// Phrases that strongly indicate an action item. Case-insensitive
    /// substring match on the segment text.
    private static let actionPhrases = [
        "action item", "i'll follow up", "you should", "please send",
        "needs to", "will send", "todo:", "to-do:", "i will", "i'll send",
        "follow up", "follow-up", "to do:", "action:", "task:", "assign"
    ]

    // MARK: - SummarizationService

    public func summarize(transcript: Transcript) async throws -> Summary {
        guard !transcript.segments.isEmpty else {
            throw SummarizationError.emptyTranscript
        }

        // Tokenize all segments and build global frequency table
        let tokenizedSegments = transcript.segments.map { segment in
            (segment: segment, tokens: tokenize(segment.text))
        }
        let frequencies = buildFrequencyTable(from: tokenizedSegments.map(\.tokens))

        // Score each segment
        typealias ScoredSegment = (segment: TranscriptSegment, score: Double)
        let scoredSegments: [ScoredSegment] = tokenizedSegments.map { segment, tokens in
            let nonStopwordTokens = tokens.filter { !Self.stopwords.contains($0) }
            guard !nonStopwordTokens.isEmpty else {
                return (segment, 0.0)
            }
            let sumFreq = nonStopwordTokens.reduce(0) { $0 + (frequencies[$1] ?? 0) }
            // Normalize by non-stopword token count to get density
            let score = Double(sumFreq) / Double(nonStopwordTokens.count)
            return (segment, score)
        }

        // Rank by score descending, take top N
        let topN = min(5, scoredSegments.count)
        let topScored = scoredSegments
            .sorted { $0.score > $1.score }
            .prefix(topN)

        // But output keyPoints in ORIGINAL chronological order
        let topSegmentIDs = Set(topScored.map { $0.segment.id })
        let keyPoints = transcript.segments
            .filter { topSegmentIDs.contains($0.id) }
            .map(\.text)

        // Overview: top 2 highest-scoring segments in chronological order
        let top2Scored = scoredSegments
            .sorted { $0.score > $1.score }
            .prefix(2)
        let top2IDs = Set(top2Scored.map { $0.segment.id })
        let overviewSegments = transcript.segments
            .filter { top2IDs.contains($0.id) }
            .map(\.text)
        let overview = overviewSegments.joined(separator: " ")

        // Decisions: scan all segments for decision-indicating phrases
        let decisions = transcript.segments.compactMap { segment -> String? in
            let lower = segment.text.lowercased()
            return Self.decisionPhrases.contains { lower.contains($0) } ? segment.text : nil
        }

        // Action items: scan all segments for action-indicating phrases
        let actionItems = transcript.segments.compactMap { segment -> Summary.ActionItem? in
            let lower = segment.text.lowercased()
            guard Self.actionPhrases.contains(where: { lower.contains($0) }) else { return nil }
            return Summary.ActionItem(
                text: segment.text,
                ownerSpeakerID: segment.speakerID
            )
        }

        return Summary(
            transcriptID: transcript.id,
            overview: overview,
            keyPoints: keyPoints,
            decisions: decisions,
            actionItems: actionItems,
            generatedByModel: "extractive-v1",
            generatedAt: Date()
        )
    }

    public func chat(transcript: Transcript, question: String) async throws -> String {
        // This is NOT a real question-answering system — it performs honest
        // keyword-overlap retrieval. It does not fabricate answers.
        let questionTokens = Set(tokenize(question).filter { !Self.stopwords.contains($0) })
        guard !questionTokens.isEmpty else {
            return "I couldn't find anything in the transcript matching your question."
        }

        // Score each segment by count of overlapping question tokens
        typealias ScoredSegment = (segment: TranscriptSegment, overlap: Int)
        let scoredSegments: [ScoredSegment] = transcript.segments.map { segment in
            let segmentTokens = Set(tokenize(segment.text).filter { !Self.stopwords.contains($0) })
            let overlap = questionTokens.intersection(segmentTokens).count
            return (segment, overlap)
        }

        let bestOverlap = scoredSegments.max(by: { $0.overlap < $1.overlap })?.overlap ?? 0
        guard bestOverlap > 0 else {
            return "I couldn't find anything in the transcript matching your question."
        }

        // Take top 3 by overlap, then output in chronological order
        let topScored = scoredSegments
            .filter { $0.overlap > 0 }
            .sorted { $0.overlap > $1.overlap }
            .prefix(3)

        let topIDs = Set(topScored.map { $0.segment.id })
        let resultSegments = transcript.segments
            .filter { topIDs.contains($0.id) }
            .map(\.text)

        return "Based on the transcript: " + resultSegments.joined(separator: " ")
    }

    // MARK: - Tokenization & Scoring Helpers

    /// Lowercase, strip punctuation, split on whitespace. Returns an array
    /// of tokens (words). Does NOT remove stopwords — caller decides.
    private func tokenize(_ text: String) -> [String] {
        // Replace punctuation with spaces, then split on whitespace
        let cleaned = text.lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
            .joined()
        return cleaned.split(separator: " ").map(String.init)
    }

    /// Build a frequency table from an array of token arrays.
    private func buildFrequencyTable(from allTokens: [[String]]) -> [String: Int] {
        var freq: [String: Int] = [:]
        for tokens in allTokens {
            for token in tokens {
                freq[token, default: 0] += 1
            }
        }
        return freq
    }
}
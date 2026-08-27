import Foundation

/// Where a SummarizationService implementation gets its model from. `.local`
/// implementations must satisfy MTM-2 (no network calls). `.cloud`
/// implementations are opt-in only and must satisfy MTM-3 (on-device PII
/// redaction before any network call, restored locally after).
public enum SummarizationBackend: Equatable, Sendable {
    case local(modelName: String)
    case cloud(providerName: String)
}

public enum SummarizationError: Error, Equatable, Sendable {
    case emptyTranscript
    case backendUnavailable
    case summarizationFailed(reason: String)
    case cloudBackendRequiresAPIKey
}

/// Produces a structured Summary from a Transcript.
public protocol SummarizationService: AnyObject, Sendable {
    var backend: SummarizationBackend { get }

    func summarize(transcript: Transcript) async throws -> Summary

    /// Answers a free-form question grounded in the transcript's content
    /// (the "AI chat" feature). Implementations must not fabricate content
    /// outside what the transcript supports.
    func chat(transcript: Transcript, question: String) async throws -> String
}

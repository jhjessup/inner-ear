import Foundation
import InnerEarRecording

/// Runs transcribe → diarize → summarize for a finished `Recording` in a
/// detached background `Task`, so a caller (the TUI run loop) never blocks
/// waiting on it — the opposite of today's `.runPipeline` TUIEffect, which
/// runs the same three steps inline and blocks the run loop until all three
/// finish. Used for `TranscriptionMode.automatic` only; manual
/// transcription (the user picking "Generate Transcript") keeps using the
/// existing blocking path, since the user is actively watching progress
/// there.
///
/// Results are collected, not pushed — a caller polls `drainCompleted()`/
/// `drainFailed()` (e.g. once per run-loop tick) to pick up whatever
/// finished since the last drain. This mirrors
/// `AVFoundationAudioCaptureService`'s `consumeAutoStoppedRecording()`
/// poll-to-drain pattern for the same reason: the run loop already polls
/// once per tick, so a push/callback mechanism would just need its own
/// thread-safety story for no real benefit.
public actor BackgroundTranscriptionCoordinator {
    public struct CompletedPipeline: Sendable {
        public let recording: Recording
        public let transcript: Transcript
        public let summary: Summary
    }

    public struct FailedPipeline: Sendable {
        public let recording: Recording
        /// `Error`'s own conformance to `Sendable` isn't guaranteed for
        /// arbitrary thrown types, so this stores a description rather
        /// than the error itself — the run loop only needs to show the
        /// user what went wrong, not inspect the error programmatically.
        public let errorDescription: String
    }

    private let transcriptionService: TranscriptionService
    private let diarizationService: DiarizationService
    private let summarizationService: SummarizationService
    private let model: TranscriptionModel

    private var completed: [CompletedPipeline] = []
    private var failed: [FailedPipeline] = []
    /// Keeps each background `Task` alive for its duration (an unretained
    /// `Task` is still running, but nothing would prevent its enclosing
    /// scope from being torn down independent of it) and lets a future
    /// caller check `isRunning(for:)` without needing its own bookkeeping.
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        transcriptionService: TranscriptionService,
        diarizationService: DiarizationService,
        summarizationService: SummarizationService,
        model: TranscriptionModel = .whisperLargeV3Turbo
    ) {
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.summarizationService = summarizationService
        self.model = model
    }

    /// Starts the pipeline for `recording` in the background and returns
    /// immediately. A `recording` already running (by `id`) is left alone
    /// — calling this twice for the same recording before it finishes is a
    /// no-op, not a second concurrent run.
    public func enqueue(_ recording: Recording) {
        guard runningTasks[recording.id] == nil else { return }
        runningTasks[recording.id] = Task { [weak self] in
            guard let self else { return }
            do {
                let transcript = try await self.transcriptionService.transcribe(
                    recording: recording,
                    model: self.model,
                    languageCode: nil
                )
                let diarized = try await self.diarizationService.diarize(transcript: transcript, recording: recording)
                let summary = try await self.summarizationService.summarize(transcript: diarized)
                await self.storeCompleted(CompletedPipeline(recording: recording, transcript: diarized, summary: summary))
            } catch {
                await self.storeFailed(FailedPipeline(recording: recording, errorDescription: "\(error)"))
            }
            await self.clearRunningTask(for: recording.id)
        }
    }

    public func isRunning(for recordingID: UUID) -> Bool {
        runningTasks[recordingID] != nil
    }

    /// Returns and clears every pipeline that completed successfully since
    /// the last call.
    public func drainCompleted() -> [CompletedPipeline] {
        defer { completed.removeAll() }
        return completed
    }

    /// Returns and clears every pipeline that failed since the last call.
    public func drainFailed() -> [FailedPipeline] {
        defer { failed.removeAll() }
        return failed
    }

    private func storeCompleted(_ result: CompletedPipeline) {
        completed.append(result)
    }

    private func storeFailed(_ result: FailedPipeline) {
        failed.append(result)
    }

    private func clearRunningTask(for id: UUID) {
        runningTasks[id] = nil
    }
}

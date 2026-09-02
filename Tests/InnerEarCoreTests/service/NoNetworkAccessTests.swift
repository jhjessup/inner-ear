import Foundation
import Testing
@testable import InnerEarCore

/// Satisfies TEST_DOCTRINE.md MTM-2: "No code path in AudioCaptureService,
/// TranscriptionService, DiarizationService, or SummarizationService issues
/// a network request when using on-device/local models." Runs a full
/// fake-backed capture -> transcribe -> diarize -> summarize -> export
/// pipeline with a `URLProtocol` registered that fails the test if ANY
/// request is attempted during the run.
///
/// Real limitation, stated honestly rather than implied: `URLProtocol`
/// registration only intercepts requests made through `URLSession`
/// configurations that consult the registered protocol list — the default
/// `URLSession.shared` configuration does pick these up, but a custom
/// `ephemeral`/background configuration with its own explicit
/// `.protocolClasses` would not, and a raw BSD socket or a non-Foundation
/// networking library bypasses this entirely. Since every service in this
/// test is a fake (none of them make real network calls in the first
/// place — that's the point of a fake), this test's actual value is as a
/// REGRESSION GUARD: if someone later swaps a fake for real code that
/// tries a `URLSession.shared` call, this catches it. It is not a complete
/// network sandbox.
struct NoNetworkAccessTests {

    // MARK: - Blocking URLProtocol

    /// Thread-safe request counter. `URLProtocol.startLoading()` can be
    /// called from an arbitrary `URLSession`-internal thread, so this needs
    /// real synchronization — mirrors the `NSLock`-protected `@unchecked
    /// Sendable` class pattern already used in this project for the same
    /// reason (see `ProgressRenderThrottle` in `TUIRunLoop.swift`).
    private final class RequestCounter: @unchecked Sendable {
        static let shared = RequestCounter()
        private let lock = NSLock()
        private var count = 0

        func increment() {
            lock.lock()
            defer { lock.unlock() }
            count += 1
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            count = 0
        }

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }

    /// Intercepts every request it's asked about, records that a request
    /// was attempted, and fails it immediately (`.cancelled`) rather than
    /// letting it hang or actually reach the network.
    private final class BlockingURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            RequestCounter.shared.increment()
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
        }

        override func stopLoading() {}
    }

    // MARK: - Test

    @Test
    func fullPipeline_withFakeServices_makesNoNetworkRequests() async throws {
        RequestCounter.shared.reset()
        URLProtocol.registerClass(BlockingURLProtocol.self)
        defer { URLProtocol.unregisterClass(BlockingURLProtocol.self) }

        let audioCapture = FakeAudioCaptureService()
        let baseTranscript = TestFixtures.transcript()
        let transcription = FakeTranscriptionService(stubbedTranscript: baseTranscript)
        let diarization = FakeDiarizationService()
        let summarization = FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: baseTranscript.id))
        let export = FakeExportService()

        // Same order the real run loop drives the pipeline in
        // (TUIRunLoop.swift's `.runPipeline`/`.startRecording`/
        // `.stopRecording`/`.exportResult` effects): capture -> transcribe
        // -> diarize -> summarize -> export.
        try await audioCapture.startCapture(captureSystemAudio: true)
        let recording = try await audioCapture.stopCapture()

        let transcript = try await transcription.transcribe(
            recording: recording,
            model: .whisperLargeV3Turbo,
            languageCode: nil
        )
        let diarizedTranscript = try await diarization.diarize(transcript: transcript, recording: recording)
        let summary = try await summarization.summarize(transcript: diarizedTranscript)
        _ = try await export.export(
            transcript: diarizedTranscript,
            summary: summary,
            format: .markdown,
            to: URL(fileURLWithPath: "/tmp/mtm2-test-export.md")
        )

        #expect(RequestCounter.shared.value == 0)
    }
}

import Foundation
import Testing
@testable import InnerEarCore

/// Tests for the concrete `AVFoundationAudioCaptureService` implementation.
///
/// Tests gated with `.enabled(if: ...)` only run when `INNEREAR_HW_TESTS=1` is
/// set in the environment, since they touch real microphone hardware and
/// require a real macOS host with a working input device.
///
/// The ungated test (`stopCapture_withNoActiveCapture_throwsNoActiveCapture`)
/// is intended to be safe everywhere — but note: even just instantiating
/// `AVFoundationAudioCaptureService` allocates an `AVAudioEngine`, which on
/// a headless CI runner with no audio devices may behave oddly. We keep it
/// ungated because the test only calls `stopCapture()` and the init is
/// cheap (it just creates a directory), but if this proves flaky in CI,
/// gate it the same way as the other two tests.
struct AudioCaptureServiceTests {

    // MARK: - Unconditional test (no hardware needed beyond a working Foundation runtime)

    @Test
    func stopCapture_withNoActiveCapture_throwsNoActiveCapture() async throws {
        let service = try AVFoundationAudioCaptureService()

        await #expect(throws: AudioCaptureError.noActiveCapture) {
            _ = try await service.stopCapture()
        }
    }

    // MARK: - Hardware-gated tests

    @Test(.enabled(if: ProcessInfo.processInfo.environment["INNEREAR_HW_TESTS"] == "1"))
    func startCapture_thenStopAfterTwoSeconds_producesRealAudioFile() async throws {
        let service = try AVFoundationAudioCaptureService()

        try await service.startCapture(captureSystemAudio: false)
        try await Task.sleep(for: .seconds(2))
        let recording = try await service.stopCapture()

        // File should exist on disk and be non-empty
        let micURL = recording.microphoneFileURL
        #expect(FileManager.default.fileExists(atPath: micURL.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: micURL.path)
        let fileSize = attrs[.size] as? Int ?? 0
        #expect(fileSize > 0)

        // Duration should be roughly 2 seconds (allow 1.5..3.0 for slop)
        #expect(recording.duration > 1.5)
        #expect(recording.duration < 3.0)

        // No system audio was requested
        #expect(!recording.hasSystemAudio)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["INNEREAR_HW_TESTS"] == "1"))
    func startCapture_whileAlreadyRecording_throwsCaptureAlreadyInProgress() async throws {
        let service = try AVFoundationAudioCaptureService()

        try await service.startCapture(captureSystemAudio: false)

        // Second startCapture without an intervening stop should throw.
        await #expect(throws: AudioCaptureError.captureAlreadyInProgress) {
            try await service.startCapture(captureSystemAudio: false)
        }

        // Clean up so the test doesn't leave a dangling recording session.
        _ = try await service.stopCapture()
    }
}

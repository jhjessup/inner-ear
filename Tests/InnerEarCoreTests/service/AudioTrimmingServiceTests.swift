import Foundation
import AVFoundation
import Testing
@testable import InnerEarCore

/// Tests for `SilenceAudioTrimmingService` against real, synthetically
/// generated audio files (never real microphone input or a real
/// transcription model) — the same "real file I/O against a temp
/// directory" pattern `RecordingStoreTests` uses, since `AVAudioFile`
/// read/write IS the thing under test here. Satisfies TEST_DOCTRINE.md
/// AX-P2 (no real audio hardware/Core ML) and AX-P4 (direct testability
/// for a new service method).
struct AudioTrimmingServiceTests {

    private let sampleRate: Double = 16000

    // MARK: - Fixtures

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioTrimmingServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a mono CAF file: `leadingSilence` seconds of silence, then
    /// `tone` seconds of a 440Hz sine (well above the default silence
    /// threshold), then `trailingSilence` seconds of silence.
    private func writeAudioFile(
        at url: URL,
        leadingSilence: TimeInterval,
        tone: TimeInterval,
        trailingSilence: TimeInterval
    ) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let totalFrames = AVAudioFrameCount((leadingSilence + tone + trailingSilence) * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buffer.frameLength = totalFrames
        let samples = buffer.floatChannelData![0]

        let leadingFrames = Int(leadingSilence * sampleRate)
        let toneFrames = Int(tone * sampleRate)

        for i in 0..<Int(totalFrames) {
            if i < leadingFrames || i >= leadingFrames + toneFrames {
                samples[i] = 0
            } else {
                let t = Double(i - leadingFrames) / sampleRate
                samples[i] = Float(0.8 * sin(2 * Double.pi * 440 * t))
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func duration(ofFileAt url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    // MARK: - Tests

    @Test
    func trimSilence_leadingAndTrailingSilence_shrinksDurationAndShiftsCreatedAt() async throws {
        let dir = try makeTempDirectory()
        let micURL = dir.appendingPathComponent("mic.caf")
        try writeAudioFile(at: micURL, leadingSilence: 1.0, tone: 1.0, trailingSilence: 1.0)

        let originalCreatedAt = Date(timeIntervalSince1970: 1_000_000)
        let recording = Recording(
            title: "Test",
            createdAt: originalCreatedAt,
            duration: 3.0,
            microphoneFileURL: micURL
        )

        let trimmed = try await SilenceAudioTrimmingService().trimSilence(recording: recording)

        #expect(trimmed.duration < recording.duration)
        #expect(trimmed.duration > 0.8 && trimmed.duration < 1.3)
        #expect(trimmed.createdAt > originalCreatedAt)
        #expect(trimmed.id == recording.id)

        let onDiskDuration = try duration(ofFileAt: micURL)
        #expect(abs(onDiskDuration - trimmed.duration) < 0.01)
    }

    @Test
    func trimSilence_noSilenceToTrim_returnsRecordingUnchanged() async throws {
        let dir = try makeTempDirectory()
        let micURL = dir.appendingPathComponent("mic.caf")
        try writeAudioFile(at: micURL, leadingSilence: 0, tone: 1.0, trailingSilence: 0)

        let recording = Recording(
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 1.0,
            microphoneFileURL: micURL
        )

        let trimmed = try await SilenceAudioTrimmingService().trimSilence(recording: recording)

        #expect(trimmed == recording)
    }

    @Test
    func trimSilence_entirelySilence_returnsRecordingUnchanged() async throws {
        let dir = try makeTempDirectory()
        let micURL = dir.appendingPathComponent("mic.caf")
        try writeAudioFile(at: micURL, leadingSilence: 1.0, tone: 0, trailingSilence: 0)

        let recording = Recording(
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 1.0,
            microphoneFileURL: micURL
        )

        let trimmed = try await SilenceAudioTrimmingService().trimSilence(recording: recording)

        #expect(trimmed == recording)
    }

    @Test
    func trimSilence_missingAudioFile_throwsAudioFileUnreadable() async throws {
        let dir = try makeTempDirectory()
        let missingURL = dir.appendingPathComponent("does-not-exist.caf")
        let recording = Recording(
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 1.0,
            microphoneFileURL: missingURL
        )

        await #expect(throws: AudioTrimmingError.audioFileUnreadable) {
            _ = try await SilenceAudioTrimmingService().trimSilence(recording: recording)
        }
    }

    @Test
    func trimSilence_withSystemAudio_trimsBothTracksToSameTimeRange() async throws {
        let dir = try makeTempDirectory()
        let micURL = dir.appendingPathComponent("mic.caf")
        let systemURL = dir.appendingPathComponent("system.caf")
        try writeAudioFile(at: micURL, leadingSilence: 1.0, tone: 1.0, trailingSilence: 1.0)
        // System track has tone across the whole 3s window — independently
        // silence-detecting it would find nothing to trim. It should still
        // get trimmed to match the mic track's detected non-silent range,
        // so the two tracks (and the transcript timestamps derived from
        // the trimmed mic file) stay aligned.
        try writeAudioFile(at: systemURL, leadingSilence: 0, tone: 3.0, trailingSilence: 0)

        let recording = Recording(
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 3.0,
            microphoneFileURL: micURL,
            systemAudioFileURL: systemURL
        )

        let trimmed = try await SilenceAudioTrimmingService().trimSilence(recording: recording)

        let micDuration = try duration(ofFileAt: micURL)
        let systemDuration = try duration(ofFileAt: systemURL)
        #expect(abs(micDuration - systemDuration) < 0.01)
        #expect(abs(trimmed.duration - systemDuration) < 0.01)
    }
}

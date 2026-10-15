import Foundation
import AVFoundation

public enum AudioTrimmingError: Error, Equatable, Sendable {
    case audioFileUnreadable
    case writeFailed(reason: String)
}

/// Trims leading/trailing silence from a finished recording's audio
/// file(s). Runs automatically as part of the transcription phase (see
/// `TUIRunLoop`'s `.runPipeline` effect, which calls this before handing
/// the recording to `TranscriptionService`) — cutting dead air at the
/// start/end both speeds up on-device transcription and keeps segment
/// timestamps meaningful.
public protocol AudioTrimmingService: AnyObject, Sendable {
    /// Trim silence from `recording`'s audio file(s) in place (overwriting
    /// the original files on disk) and return an updated `Recording`
    /// reflecting the new `duration` and shifted `createdAt`. If there's no
    /// detectable silence to trim, or the recording is silence throughout,
    /// the original `Recording` is returned unchanged — trimming never
    /// produces an empty file.
    ///
    /// Side effect: overwrites `recording.microphoneFileURL` and, if
    /// present, `recording.systemAudioFileURL` on disk (AX-P3).
    func trimSilence(recording: Recording) async throws -> Recording
}

/// Amplitude-threshold silence trimmer built on `AVAudioFile`/
/// `AVAudioPCMBuffer` — no WhisperKit/Core ML involved, so it has no
/// dependency on a loaded transcription model and no network access.
public final class SilenceAudioTrimmingService: AudioTrimmingService, Sendable {
    private let amplitudeThreshold: Float
    /// Window size used to scan for the first/last non-silent audio. Small
    /// enough not to clip the start of a soft-spoken first word, large
    /// enough that the scan over a long recording stays fast.
    private let windowDuration: TimeInterval

    public init(
        amplitudeThreshold: Float = AudioSilenceDetector.defaultAmplitudeThreshold,
        windowDuration: TimeInterval = 0.05
    ) {
        self.amplitudeThreshold = amplitudeThreshold
        self.windowDuration = windowDuration
    }

    public func trimSilence(recording: Recording) async throws -> Recording {
        guard let micRange = try detectNonSilentRange(fileURL: recording.microphoneFileURL) else {
            return recording
        }

        try trimFile(at: recording.microphoneFileURL, startFrame: micRange.startFrame, endFrame: micRange.endFrame)

        let timeRange = micRange.timeRange
        if let systemURL = recording.systemAudioFileURL,
           FileManager.default.fileExists(atPath: systemURL.path) {
            // Trim the system-audio track to the SAME time range as the mic
            // track (derived above), rather than independently silence-
            // detecting it — trimming the two tracks to different ranges
            // would desync them relative to each other and to the
            // transcript timestamps, which are produced from the
            // now-trimmed mic file.
            try trimFile(at: systemURL, toTimeRange: timeRange)
        }

        return Recording(
            id: recording.id,
            title: recording.title,
            createdAt: recording.createdAt.addingTimeInterval(timeRange.start),
            duration: timeRange.end - timeRange.start,
            microphoneFileURL: recording.microphoneFileURL,
            systemAudioFileURL: recording.systemAudioFileURL
        )
    }

    // MARK: - Detection

    private struct NonSilentRange {
        let startFrame: AVAudioFramePosition
        let endFrame: AVAudioFramePosition
        let sampleRate: Double

        var timeRange: (start: TimeInterval, end: TimeInterval) {
            (TimeInterval(Double(startFrame) / sampleRate), TimeInterval(Double(endFrame) / sampleRate))
        }
    }

    /// Scans `fileURL` for the first and last non-silent window. Returns
    /// `nil` when there's nothing worth trimming: the file is silence
    /// throughout (trimming to zero-length would destroy data, not clean
    /// it up) or already starts/ends right at non-silent audio.
    private func detectNonSilentRange(fileURL: URL) throws -> NonSilentRange? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AudioTrimmingError.audioFileUnreadable
        }
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: fileURL)
        } catch {
            throw AudioTrimmingError.audioFileUnreadable
        }

        let format = file.processingFormat
        let totalFrames = file.length
        guard totalFrames > 0, format.channelCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            return nil
        }
        do {
            try file.read(into: buffer)
        } catch {
            throw AudioTrimmingError.audioFileUnreadable
        }
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelCount = Int(format.channelCount)
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return nil }

        func samples(start: Int, length: Int) -> [Float] {
            let end = min(start + length, frameCount)
            guard start < end else { return [] }
            var result: [Float] = []
            result.reserveCapacity((end - start) * channelCount)
            for channel in 0..<channelCount {
                let channelSamples = channelData[channel]
                result.append(contentsOf: UnsafeBufferPointer(start: channelSamples + start, count: end - start))
            }
            return result
        }

        let step = max(1, Int(windowDuration * format.sampleRate))

        var firstNonSilent = 0
        while firstNonSilent < frameCount,
              AudioSilenceDetector.isSilent(samples(start: firstNonSilent, length: step), threshold: amplitudeThreshold) {
            firstNonSilent += step
        }
        // Whole file is silence — nothing usable to trim to.
        guard firstNonSilent < frameCount else { return nil }

        var lastNonSilentEnd = frameCount
        while lastNonSilentEnd > firstNonSilent {
            let windowStart = max(firstNonSilent, lastNonSilentEnd - step)
            guard AudioSilenceDetector.isSilent(
                samples(start: windowStart, length: lastNonSilentEnd - windowStart),
                threshold: amplitudeThreshold
            ) else { break }
            lastNonSilentEnd = windowStart
        }

        guard firstNonSilent > 0 || lastNonSilentEnd < frameCount else { return nil }

        return NonSilentRange(
            startFrame: AVAudioFramePosition(firstNonSilent),
            endFrame: AVAudioFramePosition(lastNonSilentEnd),
            sampleRate: format.sampleRate
        )
    }

    // MARK: - Trimming

    private func trimFile(at url: URL, toTimeRange timeRange: (start: TimeInterval, end: TimeInterval)) throws {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioTrimmingError.audioFileUnreadable
        }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition((timeRange.start * sampleRate).rounded())
        let endFrame = min(file.length, AVAudioFramePosition((timeRange.end * sampleRate).rounded()))
        try trimFile(at: url, startFrame: startFrame, endFrame: endFrame)
    }

    /// Rewrites the audio file at `url` to contain only `[startFrame,
    /// endFrame)`, in place.
    ///
    /// Side effect: overwrites `url` on disk (AX-P3). Writes to a sibling
    /// temp file first and atomically swaps it in, since `AVAudioFile`
    /// can't safely read and write the same URL at once.
    private func trimFile(at url: URL, startFrame: AVAudioFramePosition, endFrame: AVAudioFramePosition) throws {
        guard endFrame > startFrame else { return }

        let sourceFile: AVAudioFile
        do {
            sourceFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioTrimmingError.audioFileUnreadable
        }
        let format = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(endFrame - startFrame)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioTrimmingError.writeFailed(reason: "could not allocate trim buffer")
        }
        sourceFile.framePosition = startFrame
        do {
            try sourceFile.read(into: buffer, frameCount: frameCount)
        } catch {
            throw AudioTrimmingError.writeFailed(reason: "\(error)")
        }

        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".trim-\(UUID().uuidString)-\(url.lastPathComponent)")
        do {
            let outFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try outFile.write(from: buffer)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioTrimmingError.writeFailed(reason: "\(error)")
        }

        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioTrimmingError.writeFailed(reason: "\(error)")
        }
    }
}

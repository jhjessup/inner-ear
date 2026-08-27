#!/usr/bin/env swift
// =============================================================================
// generate-sample-audio.swift — Produce a small synthetic WAV fixture
// =============================================================================
// Generates a ~3 second single-channel 16 kHz mono WAV file containing a
// simple sine-wave tone. This is a PIPELINE / PLUMBING fixture, not a
// transcription-accuracy test: WhisperKit will not return real words for
// a pure tone, but the file will exercise audio decoding, segment
// emission, and the full Transcript -> RecordingStore save path end to
// end.
//
// Usage:
//   swift scripts/generate-fixtures/generate-sample-audio.swift
//
// Output:
//   Tests/InnerEarCoreTests/Fixtures/sample-3s.wav
// =============================================================================
import AVFoundation
import Foundation

let outputPath = "Tests/InnerEarCoreTests/Fixtures/sample-3s.wav"
let sampleRate: Double = 16_000
let durationSeconds: Double = 3.0
let frequency: Double = 440.0 // A4 — purely arbitrary for a fixture
let amplitude: Float = 0.25 // gentle; avoid clipping

let outputURL = URL(fileURLWithPath: outputPath)
let outputDir = outputURL.deletingLastPathComponent()
try? FileManager.default.createDirectory(
    at: outputDir,
    withIntermediateDirectories: true
)

// AVAudioFile expects a file format; for plain 16-bit PCM mono WAV:
//   - commonFormat: .pcmFormatInt16
//   - sampleRate:   16 kHz (matches typical ASR input)
//   - channels:     1
guard
    let format = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: true
    )
else {
    fputs("Failed to create AVAudioFormat\n", stderr)
    exit(1)
}

// Remove any pre-existing file so AVAudioFile.create fails loudly if it
// can't write, rather than silently overwriting with corrupt data.
try? FileManager.default.removeItem(at: outputURL)

let file: AVAudioFile
do {
    file = try AVAudioFile(
        forWriting: outputURL,
        settings: format.settings,
        commonFormat: .pcmFormatInt16,
        interleaved: true
    )
} catch {
    fputs("Failed to open output file at \(outputPath): \(error)\n", stderr)
    exit(1)
}

let totalFrames = AVAudioFrameCount(sampleRate * durationSeconds)
guard
    let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: totalFrames
    )
else {
    fputs("Failed to allocate AVAudioPCMBuffer\n", stderr)
    exit(1)
}
buffer.frameLength = totalFrames

guard let channelData = buffer.int16ChannelData else {
    fputs("Buffer has no int16 channel data\n", stderr)
    exit(1)
}

let twoPi = 2.0 * Double.pi
let phaseStep = twoPi * frequency / sampleRate

let pointer = channelData[0]
for frame in 0..<Int(totalFrames) {
    // Modulate amplitude with a slow envelope so the start/end of the
    // file aren't a hard zero->full-level click.
    let envelope: Float = {
        let fadeFrames = Int(sampleRate * 0.05) // 50 ms fade
        if frame < fadeFrames {
            return Float(frame) / Float(fadeFrames)
        } else if frame > Int(totalFrames) - fadeFrames {
            return Float(Int(totalFrames) - frame) / Float(fadeFrames)
        } else {
            return 1.0
        }
    }()
    let sample = sin(phaseStep * Double(frame)) * Double(amplitude * envelope)
    pointer[frame] = Int16(max(-1.0, min(1.0, sample)) * Double(Int16.max))
}

do {
    try file.write(from: buffer)
} catch {
    fputs("Failed to write WAV file: \(error)\n", stderr)
    exit(1)
}

print("Wrote \(outputPath) (\(Int(durationSeconds * sampleRate)) samples @ \(Int(sampleRate)) Hz, mono, 16-bit PCM).")

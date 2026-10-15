import Foundation

/// Pure amplitude-based silence detection, shared by two call sites that
/// need the identical RMS math: `AVFoundationAudioCaptureService`'s live
/// auto-stop-after-silence watchdog (checking each freshly-captured buffer)
/// and `SilenceAudioTrimmingService`'s leading/trailing-silence scan over a
/// finished recording. No AVFoundation/CoreAudio types here — just `[Float]`
/// in, `Bool`/`Float` out — so it's directly unit-testable against synthetic
/// sample data without touching real audio hardware (TEST_DOCTRINE.md AX-P2).
public enum AudioSilenceDetector {
    /// RMS amplitude below which a window of samples counts as silence.
    /// ~0.02 is roughly -34 dBFS — well below normal speech level but above
    /// typical room-noise/mic-hiss floor, so quiet speech isn't mistaken
    /// for silence.
    public static let defaultAmplitudeThreshold: Float = 0.02

    /// Root-mean-square amplitude of `samples`. Empty input is treated as
    /// silence (0), not an error — there's nothing to measure.
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    public static func isSilent(_ samples: [Float], threshold: Float = defaultAmplitudeThreshold) -> Bool {
        rms(samples) <= threshold
    }
}

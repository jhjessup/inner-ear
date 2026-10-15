import Foundation
import Testing
@testable import InnerEarCore

/// Tests for `AudioSilenceDetector`'s pure RMS-amplitude math. Synthetic
/// `[Float]` sample arrays only — no AVFoundation, no real audio hardware,
/// no Core ML — per TEST_DOCTRINE.md AX-P2.
struct AudioSilenceDetectorTests {

    @Test
    func rms_emptySamples_isZero() {
        #expect(AudioSilenceDetector.rms([]) == 0)
    }

    @Test
    func rms_allZeroSamples_isZero() {
        #expect(AudioSilenceDetector.rms([0, 0, 0, 0]) == 0)
    }

    @Test
    func rms_constantAmplitudeSamples_equalsThatAmplitude() {
        let samples = [Float](repeating: 0.5, count: 100)
        #expect(abs(AudioSilenceDetector.rms(samples) - 0.5) < 0.0001)
    }

    @Test
    func isSilent_belowThreshold_isTrue() {
        let quiet = [Float](repeating: 0.001, count: 100)
        #expect(AudioSilenceDetector.isSilent(quiet))
    }

    @Test
    func isSilent_atExactThreshold_isTrue() {
        let samples = [Float](repeating: AudioSilenceDetector.defaultAmplitudeThreshold, count: 100)
        #expect(AudioSilenceDetector.isSilent(samples))
    }

    @Test
    func isSilent_aboveThreshold_isFalse() {
        let loud = [Float](repeating: 0.5, count: 100)
        #expect(!AudioSilenceDetector.isSilent(loud))
    }

    @Test
    func isSilent_customThreshold_overridesDefault() {
        let samples = [Float](repeating: 0.1, count: 100)
        #expect(AudioSilenceDetector.isSilent(samples, threshold: 0.2))
        #expect(!AudioSilenceDetector.isSilent(samples, threshold: 0.05))
    }

    @Test
    func isSilent_emptySamples_isTrue() {
        #expect(AudioSilenceDetector.isSilent([]))
    }
}

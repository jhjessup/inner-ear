import Foundation

/// Live capture state, published by an `AudioCaptureService` implementation
/// while a recording is in progress.
public enum CaptureState: Equatable, Sendable {
    case idle
    case recording(elapsed: TimeInterval)
    case stopping
}

public enum AudioCaptureError: Error, Equatable, Sendable {
    case microphonePermissionDenied
    case systemAudioPermissionDenied
    case captureAlreadyInProgress
    case noActiveCapture
    case deviceUnavailable
}

/// Captures microphone audio (channel 1, always "Speaker 1" / the local user)
/// and, optionally, system audio (channel 2, remote participants in a call)
/// as two independent local files. Implementations back this with
/// AVFoundation / ScreenCaptureKit; nothing here ever touches the network.
public protocol AudioCaptureService: AnyObject, Sendable {
    /// Begin recording. `captureSystemAudio: true` requires Screen Recording
    /// permission on macOS in addition to microphone permission.
    ///
    /// `autoStopAfterSilence`, when non-nil, has the implementation watch
    /// for that much continuous silence (no speech on mic or system audio)
    /// and automatically stop the capture itself, without any caller action
    /// — see `consumeAutoStoppedRecording()` for how a caller notices this
    /// happened. `nil` disables auto-stop entirely.
    func startCapture(captureSystemAudio: Bool, autoStopAfterSilence: TimeInterval?) async throws

    /// Stop the active capture and return the finished Recording metadata.
    @discardableResult
    func stopCapture() async throws -> Recording

    /// Current capture state, for UI binding.
    var state: CaptureState { get async }

    /// If a prior `startCapture` with non-nil `autoStopAfterSilence` has
    /// since auto-stopped (the silence threshold was reached) WITHOUT an
    /// explicit `stopCapture()` call, returns that finished `Recording`
    /// exactly once and clears it; returns `nil` otherwise. A caller that
    /// starts a silence-bounded capture should poll this periodically (e.g.
    /// alongside other idle UI polling) to notice an auto-stop and
    /// persist/display the result — the normal explicit-`stopCapture()`
    /// path already has the `Recording` directly and never needs this.
    func consumeAutoStoppedRecording() async -> Recording?
}

extension AudioCaptureService {
    /// Convenience overload for callers that don't want silence-based
    /// auto-stop — this is what keeps existing call sites (`InnerEarCLI`'s
    /// `record` command, the test suite) compiling unchanged.
    public func startCapture(captureSystemAudio: Bool) async throws {
        try await startCapture(captureSystemAudio: captureSystemAudio, autoStopAfterSilence: nil)
    }
}

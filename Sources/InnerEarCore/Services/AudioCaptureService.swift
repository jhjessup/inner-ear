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
    func startCapture(captureSystemAudio: Bool) async throws

    /// Stop the active capture and return the finished Recording metadata.
    @discardableResult
    func stopCapture() async throws -> Recording

    /// Current capture state, for UI binding.
    var state: CaptureState { get async }
}

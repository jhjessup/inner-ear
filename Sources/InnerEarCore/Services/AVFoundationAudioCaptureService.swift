import Foundation
import AVFoundation
// ScreenCaptureKit's types (e.g. SCShareableContent) aren't yet audited as
// Sendable in this SDK version, which trips Swift 6 strict-concurrency
// checking when they cross this actor's isolation boundary.
// @preconcurrency is Apple's documented approach for system frameworks
// not yet updated for strict concurrency checking.
@preconcurrency import ScreenCaptureKit
import CoreAudio

/// Real AudioCaptureService implementation using AVAudioEngine (mic) and ScreenCaptureKit (system audio).
/// Actor-isolated to safely manage concurrent state and async audio callbacks.
public final actor AVFoundationAudioCaptureService: AudioCaptureService, Sendable {

    // MARK: - State

    private enum InternalState: Equatable, Sendable {
        case idle
        case recording(startedAt: Date, captureSystemAudio: Bool, recordingID: UUID)
        case stopping
    }

    private var internalState: InternalState = .idle

    // MARK: - Silence Auto-Stop

    private var autoStopSilenceThreshold: TimeInterval?
    private var lastNonSilentAt: Date = Date()
    private var silenceWatchdogTask: Task<Void, Never>?
    /// Set by the silence watchdog when it auto-stops a capture; drained
    /// (read-then-clear) by `consumeAutoStoppedRecording()`. A plain
    /// `stopCapture()` call never touches this — the caller already has
    /// the `Recording` it returns directly.
    private var pendingAutoStoppedRecording: Recording?

    // MARK: - Audio Engine (Microphone)

    private let audioEngine = AVAudioEngine()
    private var micAudioFile: AVAudioFile?
    private var micFileURL: URL?

    // MARK: - ScreenCaptureKit (System Audio)

    private var scStream: SCStream?
    private var systemAudioFile: AVAudioFile?
    private var systemAudioFileURL: URL?
    // Strong reference — SCStream's addStreamOutput does not guarantee it
    // retains the output object, so nothing else would keep this alive
    // between when startCapture returns and when audio callbacks arrive.
    private var systemAudioHandler: SystemAudioCaptureHandler?

    // MARK: - File Management

    private let baseAudioDirectory: URL
    private var currentRecordingDirectory: URL?

    // MARK: - Init

    public init() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseAudioDirectory = appSupport.appendingPathComponent("InnerEar/audio", isDirectory: true)
        try FileManager.default.createDirectory(at: baseAudioDirectory, withIntermediateDirectories: true)
    }

    // MARK: - AudioCaptureService Protocol

    public var state: CaptureState {
        get async {
            switch internalState {
            case .idle:
                return .idle
            case .recording(let startedAt, _, _):
                return .recording(elapsed: Date().timeIntervalSince(startedAt))
            case .stopping:
                return .stopping
            }
        }
    }

    public func startCapture(captureSystemAudio: Bool, autoStopAfterSilence: TimeInterval?) async throws {
        // Check if already recording
        guard case .idle = internalState else {
            throw AudioCaptureError.captureAlreadyInProgress
        }

        // Request microphone permission
        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            throw AudioCaptureError.microphonePermissionDenied
        }

        // Prepare recording directory
        let recordingID = UUID()
        let recordingDir = baseAudioDirectory.appendingPathComponent(recordingID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: recordingDir, withIntermediateDirectories: true)
        currentRecordingDirectory = recordingDir

        // Set up microphone capture
        let micURL = recordingDir.appendingPathComponent("mic.caf")
        micFileURL = micURL
        try setupMicrophoneCapture(to: micURL)

        // Set up system audio capture if requested
        if captureSystemAudio {
            let systemURL = recordingDir.appendingPathComponent("system.caf")
            systemAudioFileURL = systemURL
            do {
                try await setupSystemAudioCapture(to: systemURL)
            } catch let error as AudioCaptureError {
                // Clean up mic capture if system audio setup fails
                await cleanupMicrophoneCapture()
                throw error
            } catch {
                await cleanupMicrophoneCapture()
                throw AudioCaptureError.deviceUnavailable
            }
        }

        // Start microphone engine
        try audioEngine.start()

        // Start system audio stream if configured
        if captureSystemAudio, let scStream = scStream {
            try await scStream.startCapture()
        }

        // Update state
        internalState = .recording(startedAt: Date(), captureSystemAudio: captureSystemAudio, recordingID: recordingID)

        // Arm silence auto-stop, if requested.
        autoStopSilenceThreshold = autoStopAfterSilence
        lastNonSilentAt = Date()
        if let autoStopAfterSilence {
            startSilenceWatchdog(threshold: autoStopAfterSilence)
        }
    }

    @discardableResult
    public func stopCapture() async throws -> Recording {
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = nil
        return try await performStop()
    }

    public func consumeAutoStoppedRecording() async -> Recording? {
        defer { pendingAutoStoppedRecording = nil }
        return pendingAutoStoppedRecording
    }

    /// Polls once a second for `autoStopSilenceThreshold` continuous
    /// silence on either audio track and, if reached, stops the capture
    /// itself (stashing the result for `consumeAutoStoppedRecording()`).
    /// Polling rather than a timer/notification is the simplest correct
    /// option for an actor-isolated check, and 1s resolution is more than
    /// enough precision for a threshold measured in minutes.
    private func startSilenceWatchdog(threshold: TimeInterval) {
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self else { return }
                guard await self.silenceThresholdExceeded() else { continue }
                if let recording = try? await self.performStop() {
                    await self.storeAutoStoppedRecording(recording)
                }
                return
            }
        }
    }

    private func silenceThresholdExceeded() -> Bool {
        guard case .recording = internalState, let threshold = autoStopSilenceThreshold else { return false }
        return Date().timeIntervalSince(lastNonSilentAt) >= threshold
    }

    private func storeAutoStoppedRecording(_ recording: Recording) {
        pendingAutoStoppedRecording = recording
    }

    /// The actual stop-and-finalize logic, shared by the public
    /// `stopCapture()` (which first cancels the silence watchdog) and the
    /// watchdog itself (which calls this directly — cancelling itself from
    /// inside its own running Task body would be a no-op anyway, and
    /// `silenceWatchdogTask` still needs clearing, which `stopCapture()`'s
    /// path handles; the watchdog path leaves it be since the Task is
    /// about to end on its own).
    private func performStop() async throws -> Recording {
        // Must be in recording state
        guard case .recording(let startedAt, let captureSystemAudio, let recordingID) = internalState else {
            throw AudioCaptureError.noActiveCapture
        }

        internalState = .stopping

        let elapsed = Date().timeIntervalSince(startedAt)

        // Stop system audio first (if active)
        if captureSystemAudio, let scStream = scStream {
            do {
                try await scStream.stopCapture()
            } catch {
                // Log but continue - we still want to finalize mic capture
                print("Warning: Failed to stop system audio stream: \(error)")
            }
            self.scStream = nil
        }

        // Stop microphone engine
        await cleanupMicrophoneCapture()

        // Finalize system audio file
        if captureSystemAudio {
            await finalizeSystemAudioFile()
        }

        // micFileURL is set by startCapture(...) before internalState ever
        // becomes .recording, and the guard above proves we were in
        // .recording — so this should be unreachable in practice. Guarding
        // instead of force-unwrapping means a future refactor that breaks
        // that invariant fails with a normal thrown error instead of
        // crashing the whole process.
        //
        // Bound to a differently-named local (not `guard let micFileURL`)
        // deliberately: shadowing the property name would make it refer to
        // this new immutable local for the REST of the function — including
        // the `micFileURL = nil` reset below, which needs to reach the
        // actual `var` property, not a `let` shadow of it.
        guard let resolvedMicFileURL = micFileURL else {
            internalState = .idle
            throw AudioCaptureError.noActiveCapture
        }

        // Build Recording struct
        let recording = Recording(
            id: recordingID,
            title: "Recording \(DateFormatter.recordingTitle.string(from: startedAt))",
            createdAt: startedAt,
            duration: elapsed,
            microphoneFileURL: resolvedMicFileURL,
            systemAudioFileURL: systemAudioFileURL
        )

        // Reset state
        internalState = .idle
        currentRecordingDirectory = nil
        micFileURL = nil
        systemAudioFileURL = nil
        autoStopSilenceThreshold = nil

        return recording
    }

    // MARK: - Microphone Capture (AVAudioEngine)

    private func setupMicrophoneCapture(to url: URL) throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create AVAudioFile for writing (CAF format, matching input format)
        micAudioFile = try AVAudioFile(forWriting: url, settings: inputFormat.settings)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            // AVAudioPCMBuffer isn't Sendable-audited in this SDK, so Swift 6
            // strict concurrency flags handing it into a new Task directly.
            // It's an immutable snapshot by the time the tap delivers it, so
            // boxing it as @unchecked Sendable to cross the boundary is safe.
            let box = UncheckedSendableBox(value: buffer)
            Task { [weak self] in
                await self?.writeMicBuffer(box.value)
            }
        }
    }

    private func writeMicBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard let micAudioFile = micAudioFile else { return }
        trackSilence(for: buffer)
        do {
            try micAudioFile.write(from: buffer)
        } catch {
            print("Error writing microphone buffer: \(error)")
        }
    }

    /// Updates `lastNonSilentAt` whenever `buffer`'s RMS amplitude is above
    /// the silence threshold. No-op when auto-stop-after-silence isn't
    /// armed for the current capture, so a normal recording pays zero
    /// extra cost per buffer beyond the nil check. Called from both the
    /// mic tap and the system-audio stream output — either track having
    /// audio counts as "not silent", since a meeting with the user quietly
    /// listening (not talking) is still an active meeting.
    private func trackSilence(for buffer: AVAudioPCMBuffer) {
        guard autoStopSilenceThreshold != nil, let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        var samples: [Float] = []
        samples.reserveCapacity(frameCount * channelCount)
        for channel in 0..<channelCount {
            samples.append(contentsOf: UnsafeBufferPointer(start: channelData[channel], count: frameCount))
        }
        if !AudioSilenceDetector.isSilent(samples) {
            lastNonSilentAt = Date()
        }
    }

    private func cleanupMicrophoneCapture() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        micAudioFile = nil
    }

    // MARK: - System Audio Capture (ScreenCaptureKit)

    private func setupSystemAudioCapture(to url: URL) async throws {
        // Get shareable content (this will fail if Screen Recording permission not granted)
        let shareableContent: SCShareableContent
        do {
            shareableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            // Check if it's a permission error
            if let nsError = error as NSError?,
               nsError.domain == "SCStreamErrorDomain" || nsError.domain.contains("ScreenCapture") {
                throw AudioCaptureError.systemAudioPermissionDenied
            }
            throw error
        }

        // Create audio-only stream configuration
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true // Don't capture our own audio
        config.sampleRate = 48000
        config.channelCount = 2

        // We want all system audio, not a specific window — filter by display.
        guard let display = shareableContent.displays.first else {
            throw AudioCaptureError.deviceUnavailable
        }
        let displayFilter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        scStream = SCStream(filter: displayFilter, configuration: config, delegate: nil)

        // systemAudioFile is intentionally NOT created here — its format is
        // derived from the first real buffer's actual stream description in
        // writeSystemAudioBuffer, since guessing the format upfront risks a
        // mismatch against whatever ScreenCaptureKit actually delivers,
        // which would make every AVAudioFile.write(from:) call below throw.
        systemAudioFileURL = url

        let handler = SystemAudioCaptureHandler(captureService: self)
        systemAudioHandler = handler
        try scStream?.addStreamOutput(
            handler,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "com.innerear.system-audio-capture", qos: .userInitiated)
        )
    }

    // fileprivate, not private — SystemAudioCaptureHandler (a separate type
    // in this same file) needs to call this from its SCStreamOutput
    // callback. Swift's `private` restricts access to the enclosing
    // declaration itself, not just the file.
    fileprivate func writeSystemAudioBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard let url = systemAudioFileURL else { return }

        // Lazily open the file using the real format of the first buffer we
        // actually receive, rather than a guessed format set up in advance.
        if systemAudioFile == nil {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
                  let format = AVAudioFormat(streamDescription: asbd) else {
                return
            }
            systemAudioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        }
        guard let systemAudioFile else { return }

        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                guard let pcmBuffer = AVAudioPCMBuffer(
                    pcmFormat: systemAudioFile.processingFormat,
                    bufferListNoCopy: audioBufferList.unsafePointer
                ) else { return }
                trackSilence(for: pcmBuffer)
                try systemAudioFile.write(from: pcmBuffer)
            }
        } catch {
            print("Error writing system audio buffer: \(error)")
        }
    }

    private func finalizeSystemAudioFile() async {
        systemAudioFile = nil
        systemAudioHandler = nil
    }

    // MARK: - Permissions

    private func requestMicrophonePermission() async -> Bool {
        // Use AVAudioApplication for macOS 14.4+, fallback to AVCaptureDevice
        if #available(macOS 14.4, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

// MARK: - System Audio Capture Handler

private final class SystemAudioCaptureHandler: NSObject, SCStreamOutput, @unchecked Sendable {
    weak var captureService: AVFoundationAudioCaptureService?

    init(captureService: AVFoundationAudioCaptureService) {
        self.captureService = captureService
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        // See the matching comment in setupMicrophoneCapture — CMSampleBuffer
        // isn't Sendable-audited either.
        let box = UncheckedSendableBox(value: sampleBuffer)
        Task { [weak captureService] in
            await captureService?.writeSystemAudioBuffer(box.value)
        }
    }
}

/// Shuttles a non-Sendable-audited value across a Task boundary. Only safe
/// to use for values that are effectively immutable snapshots by the time
/// they're boxed (true for both AVAudioPCMBuffer from a tap callback and
/// CMSampleBuffer from an SCStreamOutput callback — neither is mutated
/// again by the framework after delivery).
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let recordingTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
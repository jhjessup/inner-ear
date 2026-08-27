import Foundation
import AVFoundation
import ScreenCaptureKit
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

    public func startCapture(captureSystemAudio: Bool) async throws {
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
    }

    @discardableResult
    public func stopCapture() async throws -> Recording {
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

        // Build Recording struct
        let recording = Recording(
            id: recordingID,
            title: "Recording \(DateFormatter.recordingTitle.string(from: startedAt))",
            createdAt: startedAt,
            duration: elapsed,
            microphoneFileURL: micFileURL!,
            systemAudioFileURL: systemAudioFileURL
        )

        // Reset state
        internalState = .idle
        currentRecordingDirectory = nil
        micFileURL = nil
        systemAudioFileURL = nil

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
            Task { [weak self] in
                await self?.writeMicBuffer(buffer)
            }
        }
    }

    private func writeMicBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard let micAudioFile = micAudioFile else { return }
        do {
            try micAudioFile.write(from: buffer)
        } catch {
            print("Error writing microphone buffer: \(error)")
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

    private func writeSystemAudioBuffer(_ sampleBuffer: CMSampleBuffer) async {
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
        Task { [weak captureService] in
            await captureService?.writeSystemAudioBuffer(sampleBuffer)
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let recordingTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
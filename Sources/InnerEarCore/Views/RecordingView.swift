import SwiftUI

/// Root recording screen: start/stop control, live capture state, and the
/// resulting transcript once processing completes.
public struct RecordingView: View {
    @Bindable private var viewModel: RecordingViewModel
    @State private var captureSystemAudio = true
    @State private var selectedModel: TranscriptionModel = .whisperLargeV3Turbo

    public init(viewModel: RecordingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Toggle("Capture system audio (Zoom/Teams/Meet)", isOn: $captureSystemAudio)

            Picker("Model", selection: $selectedModel) {
                ForEach(TranscriptionModel.allCases, id: \.self) { model in
                    Text(model.rawValue).tag(model)
                }
            }
            .pickerStyle(.segmented)

            controls

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if let transcript = viewModel.transcript {
                transcriptView(transcript)
            }
        }
        .padding()
    }

    private var header: some View {
        Group {
            switch viewModel.captureState {
            case .idle:
                Text("Ready to record").font(.headline)
            case .recording(let elapsed):
                Text("Recording — \(Int(elapsed))s").font(.headline).foregroundStyle(.red)
            case .stopping:
                Text("Finishing up…").font(.headline)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button("Start") {
                Task { await viewModel.startRecording(captureSystemAudio: captureSystemAudio) }
            }
            .disabled(viewModel.captureState != .idle)

            Button("Stop & Process") {
                Task { await viewModel.stopRecordingAndProcess(model: selectedModel) }
            }
            .disabled(viewModel.captureState == .idle)
        }
    }

    private func transcriptView(_ transcript: Transcript) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(transcript.segments) { segment in
                    HStack(alignment: .top) {
                        Text(transcript.speaker(for: segment)?.label ?? "Unknown")
                            .bold()
                            .foregroundStyle(Color(hex: transcript.speaker(for: segment)?.colorHex))
                        Text(segment.text)
                    }
                }
            }
        }
    }
}

private extension Color {
    init(hex: String?) {
        guard let hex, let value = UInt32(hex.trimmingCharacters(in: .init(charactersIn: "#")), radix: 16) else {
            self = .primary
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

import Foundation
import InnerEarCore

/// Pure rendering logic for the TUI. Given a state and terminal dimensions,
/// returns an array of lines (one per row) ready to be written to the
/// terminal. No I/O, no side effects — fully testable.
public enum TUIRenderer {
    /// Render the current state to a line array bounded by `width` × `height`.
    ///
    /// - Parameters:
    ///   - state: The TUI state to render.
    ///   - width: Terminal width in columns (characters). Lines longer than
    ///     this are truncated with "…".
    ///   - height: Terminal height in rows. The returned array will never
    ///     have more than `height` elements.
    /// - Returns: An array of strings, one per screen line, top to bottom.
    public static func render(state: TUIState, width: Int, height: Int) -> [String] {
        var lines: [String] = []

        switch state {
        case .mainMenu:
            lines = renderMainMenu(width: width)

        case .recordPrompt:
            lines = renderRecordPrompt(width: width)

        case .recording(let startedAt, let captureSystemAudio):
            lines = renderRecording(startedAt: startedAt, captureSystemAudio: captureSystemAudio, width: width)

        case .recordingSaved(let recording):
            lines = renderRecordingSaved(recording: recording, width: width)

        case .browsing(let recordings, let selectedIndex):
            lines = renderBrowsing(recordings: recordings, selectedIndex: selectedIndex, width: width, height: height)

        case .processing(let recording, let statusLine):
            lines = renderProcessing(recording: recording, statusLine: statusLine, width: width)

        case .viewingResults(let transcript, let summary, let scrollOffset):
            lines = renderViewingResults(transcript: transcript, summary: summary, scrollOffset: scrollOffset, width: width, height: height)

        case .errorMessage(let message):
            lines = renderErrorMessage(message, width: width)
        }

        // Ensure we never exceed the terminal height.
        if lines.count > height {
            lines = Array(lines.prefix(height))
        }
        return lines
    }

    // MARK: - Private Rendering Helpers

    private static func renderMainMenu(width: Int) -> [String] {
        var lines: [String] = []
        lines.append(truncate("InnerEar", width: width))
        lines.append("")
        lines.append(truncate("[1] Record", width: width))
        lines.append(truncate("[2] Browse Recordings", width: width))
        lines.append(truncate("[q] Quit", width: width))
        return lines
    }

    private static func renderRecordPrompt(width: Int) -> [String] {
        return [truncate("Include system audio? [y/n]  [b] Back", width: width)]
    }

    private static func renderRecording(startedAt: Date, captureSystemAudio: Bool, width: Int) -> [String] {
        let elapsed = Date().timeIntervalSince(startedAt)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let timeStr = String(format: "%02d:%02d", minutes, seconds)
        let sysAudioStr = captureSystemAudio ? "on" : "off"
        let line = "Recording... \(timeStr)  (system audio: \(sysAudioStr))  [s] Stop"
        return [truncate(line, width: width)]
    }

    private static func renderRecordingSaved(recording: Recording, width: Int) -> [String] {
        var lines: [String] = []
        let idStr = recording.id.uuidString
        lines.append(truncate("Recording saved: \(idStr)", width: width))
        lines.append(truncate("[Enter] Process now   [b] Back to menu", width: width))
        return lines
    }

    private static func renderBrowsing(recordings: [Recording], selectedIndex: Int, width: Int, height: Int) -> [String] {
        var lines: [String] = []

        if recordings.isEmpty {
            lines.append(truncate("No recordings yet. [b] Back", width: width))
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            // Reserve 2 lines for footer.
            let contentHeight = max(1, height - 2)
            let startIndex = max(0, min(selectedIndex - contentHeight / 2, recordings.count - contentHeight))
            let endIndex = min(startIndex + contentHeight, recordings.count)

            for i in startIndex..<endIndex {
                let recording = recordings[i]
                let dateStr = formatter.string(from: recording.createdAt)
                let prefix = (i == selectedIndex) ? "> " : "  "
                let line = "\(prefix)\(recording.title)  —  \(dateStr)"
                lines.append(truncate(line, width: width))
            }
        }

        // Footer (always shown if space permits)
        if lines.count < height {
            lines.append(truncate("[j/k] Move  [Enter] Select  [b] Back", width: width))
        }
        return lines
    }

    private static func renderProcessing(recording: Recording, statusLine: String, width: Int) -> [String] {
        var lines: [String] = []
        lines.append(truncate("Processing \(recording.title)...", width: width))
        lines.append(truncate(statusLine, width: width))
        return lines
    }

    private static func renderViewingResults(transcript: Transcript, summary: Summary?, scrollOffset: Int, width: Int, height: Int) -> [String] {
        var fullText = transcript.fullText

        if let summary = summary {
            fullText += "\n\n--- Summary ---\n"
            fullText += summary.overview + "\n"
            if !summary.keyPoints.isEmpty {
                fullText += "\nKey Points:\n"
                for point in summary.keyPoints {
                    fullText += "- \(point)\n"
                }
            }
            if !summary.decisions.isEmpty {
                fullText += "\nDecisions:\n"
                for decision in summary.decisions {
                    fullText += "- \(decision)\n"
                }
            }
            if !summary.actionItems.isEmpty {
                fullText += "\nAction Items:\n"
                for item in summary.actionItems {
                    fullText += "- \(item.text)\n"
                }
            }
        }

        // Split into lines and wrap at `width`.
        var allLines: [String] = []
        for paragraph in fullText.split(separator: "\n", omittingEmptySubsequences: false) {
            let para = String(paragraph)
            if para.isEmpty {
                allLines.append("")
            } else {
                // Simple word-wrapping by width (not word-boundary-aware for v1).
                var remaining = para
                while !remaining.isEmpty {
                    let chunk = String(remaining.prefix(width))
                    allLines.append(chunk)
                    remaining = String(remaining.dropFirst(chunk.count))
                }
            }
        }

        // Reserve 1 line for footer.
        let visibleHeight = max(1, height - 1)
        let clampedOffset = min(scrollOffset, max(0, allLines.count - visibleHeight))
        let start = clampedOffset
        let end = min(start + visibleHeight, allLines.count)

        var lines = Array(allLines[start..<end].map { truncate($0, width: width) })

        // Footer
        if lines.count < height {
            lines.append(truncate("[j/k] Scroll  [e] Export  [b] Back", width: width))
        }
        return lines
    }

    private static func renderErrorMessage(_ message: String, width: Int) -> [String] {
        var lines: [String] = []
        lines.append(truncate("Error: \(message)", width: width))
        lines.append(truncate("[b] Back", width: width))
        return lines
    }

    /// Truncate a string to `width` characters, appending "…" if truncated.
    private static func truncate(_ s: String, width: Int) -> String {
        guard s.count > width else { return s }
        let end = s.index(s.startIndex, offsetBy: max(0, width - 1))
        return String(s[..<end]) + "…"
    }
}
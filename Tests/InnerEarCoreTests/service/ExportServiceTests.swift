import Foundation
import Testing
@testable import InnerEarCore

/// Tests for the concrete FileExportService implementation.
/// Uses real FileExportService instances (not fakes) and exports TestFixtures data
/// to a temp directory, asserting file existence and content correctness.
struct ExportServiceTests {

    private let exportService = FileExportService()
    private let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("InnerEarExportTests-\(UUID().uuidString)", isDirectory: true)

    init() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    // MARK: - Markdown Export

    @Test
    func exportMarkdown_createsFileWithExpectedContent() async throws {
        let transcript = TestFixtures.transcript()
        let summary = TestFixtures.summary(transcriptID: transcript.id)
        let destination = tempDir.appendingPathComponent("test.md")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: summary,
            format: .markdown,
            to: destination
        )

        #expect(resultURL == destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(!content.isEmpty)
        #expect(content.contains("# Transcript:"))
        #expect(content.contains("Hello world"))
        #expect(content.contains("Speaker 1"))
        #expect(content.contains("## Summary"))
        #expect(content.contains("A short meeting."))
        #expect(content.contains("Point one"))
    }

    @Test
    func exportMarkdown_withoutSummary_includesTranscriptOnly() async throws {
        let transcript = TestFixtures.transcript()
        let destination = tempDir.appendingPathComponent("test-no-summary.md")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .markdown,
            to: destination
        )

        #expect(resultURL == destination)
        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(content.contains("# Transcript:"))
        #expect(content.contains("Hello world"))
        #expect(!content.contains("## Summary"))
    }

    // MARK: - Plain Text Export

    @Test
    func exportPlainText_createsFileWithExpectedContent() async throws {
        let transcript = TestFixtures.transcript()
        let summary = TestFixtures.summary(transcriptID: transcript.id)
        let destination = tempDir.appendingPathComponent("test.txt")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: summary,
            format: .plainText,
            to: destination
        )

        #expect(resultURL == destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(!content.isEmpty)
        #expect(content.contains("Transcript:"))
        #expect(content.contains("Hello world"))
        #expect(content.contains("Speaker 1"))
        #expect(content.contains("=== SUMMARY ==="))
        #expect(content.contains("A short meeting."))
        #expect(content.contains("Point one"))
        // Plain text should NOT contain markdown syntax
        #expect(!content.contains("# Transcript"))
        #expect(!content.contains("**"))
    }

    @Test
    func exportPlainText_withoutSummary_includesTranscriptOnly() async throws {
        let transcript = TestFixtures.transcript()
        let destination = tempDir.appendingPathComponent("test-no-summary.txt")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .plainText,
            to: destination
        )

        #expect(resultURL == destination)
        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(content.contains("Transcript:"))
        #expect(content.contains("Hello world"))
        #expect(!content.contains("=== SUMMARY ==="))
    }

    // MARK: - JSON Export

    @Test
    func exportJSON_createsFileThatRoundTrips() async throws {
        let transcript = TestFixtures.transcript()
        let summary = TestFixtures.summary(transcriptID: transcript.id)
        let destination = tempDir.appendingPathComponent("test.json")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: summary,
            format: .json,
            to: destination
        )

        #expect(resultURL == destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(!content.isEmpty)

        // Verify it's valid JSON that decodes back to matching data
        struct ExportPayload: Codable {
            let transcript: Transcript
            let summary: Summary?
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = content.data(using: .utf8)!
        let payload = try decoder.decode(ExportPayload.self, from: data)

        #expect(payload.transcript.id == transcript.id)
        #expect(payload.transcript.recordingID == transcript.recordingID)
        #expect(payload.transcript.languageCode == transcript.languageCode)
        #expect(payload.transcript.modelUsed == transcript.modelUsed)
        #expect(payload.transcript.segments.count == transcript.segments.count)
        #expect(payload.transcript.segments.first?.text == "Hello world")

        #expect(payload.summary != nil)
        #expect(payload.summary?.id == summary.id)
        #expect(payload.summary?.transcriptID == summary.transcriptID)
        #expect(payload.summary?.overview == summary.overview)
        #expect(payload.summary?.keyPoints == summary.keyPoints)
    }

    @Test
    func exportJSON_withoutSummary_decodesWithNilSummary() async throws {
        let transcript = TestFixtures.transcript()
        let destination = tempDir.appendingPathComponent("test-no-summary.json")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .json,
            to: destination
        )

        #expect(resultURL == destination)
        let content = try String(contentsOf: destination, encoding: .utf8)

        struct ExportPayload: Codable {
            let transcript: Transcript
            let summary: Summary?
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = content.data(using: .utf8)!
        let payload = try decoder.decode(ExportPayload.self, from: data)

        #expect(payload.transcript.id == transcript.id)
        #expect(payload.summary == nil)
    }

    // MARK: - RTF Export

    @Test
    func exportRTF_createsFileWithRTFHeader() async throws {
        let transcript = TestFixtures.transcript()
        let destination = tempDir.appendingPathComponent("test.rtf")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .rtf,
            to: destination
        )

        #expect(resultURL == destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(content.hasPrefix("{\\rtf1\\ansi"))
        #expect(content.hasSuffix("}"))
        #expect(content.contains("Hello world"))
    }

    // MARK: - Subtitles (SRT) Export

    @Test
    func exportSubtitles_createsValidSRT() async throws {
        let transcript = TestFixtures.transcript()
        let destination = tempDir.appendingPathComponent("test.srt")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .subtitles,
            to: destination
        )

        #expect(resultURL == destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(!content.isEmpty)
        #expect(content.contains("1\n"))
        #expect(content.contains("-->"))
        #expect(content.contains("Speaker 1:"))
        #expect(content.contains("Hello world"))
        // SRT format: index, timestamp range, text, blank line
        let lines = content.components(separatedBy: "\n")
        #expect(lines[0] == "1") // First subtitle index
        #expect(lines[1].contains("-->")) // Timestamp line
    }

    // MARK: - PDF Export

    @Test
    func exportPDF_createsFile() async throws {
        let transcript = TestFixtures.transcript()
        let destination = tempDir.appendingPathComponent("test.pdf")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .pdf,
            to: destination
        )

        #expect(resultURL == destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))
        // PDF may be plain text fallback on non-macOS; just verify file exists and is non-empty
        let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = attrs[.size] as? Int ?? 0
        #expect(fileSize > 0)
    }

    // MARK: - Multi-segment Transcript

    @Test
    func exportMarkdown_multipleSegments_allIncluded() async throws {
        let speaker1 = TestFixtures.speaker(label: "Alice", isLocalUser: true)
        let speaker2 = TestFixtures.speaker(label: "Bob", isLocalUser: false)
        let transcript = Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: "test-model",
            speakers: [speaker1, speaker2],
            segments: [
                TranscriptSegment(speakerID: speaker1.id, text: "First segment", startTime: 0, endTime: 1.5),
                TranscriptSegment(speakerID: speaker2.id, text: "Second segment", startTime: 1.5, endTime: 3.0),
                TranscriptSegment(speakerID: speaker1.id, text: "Third segment", startTime: 3.0, endTime: 4.5)
            ],
            generatedAt: Date()
        )
        let destination = tempDir.appendingPathComponent("multi.md")

        let resultURL = try await exportService.export(
            transcript: transcript,
            summary: nil,
            format: .markdown,
            to: destination
        )

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(content.contains("First segment"))
        #expect(content.contains("Second segment"))
        #expect(content.contains("Third segment"))
        #expect(content.contains("Alice"))
        #expect(content.contains("Bob"))
        // Timestamps should be formatted
        #expect(content.contains("00:00:00") || content.contains("00:00:01"))
    }
}
import Foundation

public enum ExportFormat: String, CaseIterable, Codable, Sendable {
    case pdf
    case markdown
    case plainText
    case rtf
    case json
    case subtitles // .srt
}

public enum ExportError: Error, Equatable, Sendable {
    case unsupportedFormat(ExportFormat)
    case writeFailed(reason: String)
}

/// Renders a Transcript (and optional Summary) to a local file in the
/// requested format. All export generation happens on-device.
public protocol ExportService: AnyObject, Sendable {
    /// Writes the export to `destinationURL` and returns that same URL on success.
    @discardableResult
    func export(
        transcript: Transcript,
        summary: Summary?,
        format: ExportFormat,
        to destinationURL: URL
    ) async throws -> URL
}

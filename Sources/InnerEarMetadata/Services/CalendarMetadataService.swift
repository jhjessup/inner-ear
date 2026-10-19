import Foundation

public enum CalendarMetadataError: Error, Equatable, Sendable {
    case accessDenied
}

/// Looks up calendar context for a recording. No network access in any
/// conforming implementation — Calendar data is local/synced by the OS,
/// never fetched directly by this app.
public protocol CalendarMetadataService: AnyObject, Sendable {
    /// The calendar event most relevant to `interval` — the one with the
    /// most time-overlap, if any exist. Returns `nil` (not an error) when
    /// no event overlaps `interval`; throws only for a genuine access/query
    /// failure (e.g. `.accessDenied`).
    func activeEvent(during interval: DateInterval) async throws -> CalendarContext?
}

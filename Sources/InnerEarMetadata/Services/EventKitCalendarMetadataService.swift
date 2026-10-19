import Foundation
import EventKit

/// Real `CalendarMetadataService` backed by `EventKit`. Fully local/on-
/// device — EventKit reads whatever calendars the OS already has synced,
/// this service makes no network calls of its own.
///
/// Requesting Calendar access from a bare SwiftPM CLI tool (no Info.plist,
/// no app bundle) works the same way microphone access already does in
/// this app: the OS still shows the TCC permission prompt, and the grant
/// attaches to the hosting process (Terminal.app in the common case) —
/// see ARCHITECTURE.md.
public final class EventKitCalendarMetadataService: CalendarMetadataService, @unchecked Sendable {
    private let eventStore = EKEventStore()

    public init() {}

    public func activeEvent(during interval: DateInterval) async throws -> CalendarContext? {
        let granted = await requestAccess()
        guard granted else {
            throw CalendarMetadataError.accessDenied
        }

        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        guard !events.isEmpty else { return nil }

        // Most-overlapping event wins when several exist in the window —
        // a more honest signal than "the first one returned" for an
        // interval that might span a meeting's actual start/end plus a
        // few minutes of setup/wrap-up on either side.
        let best = events.max { overlapDuration($0, interval) < overlapDuration($1, interval) }
        guard let best else { return nil }

        return CalendarContext(
            eventTitle: best.title ?? "Untitled Event",
            startDate: best.startDate,
            endDate: best.endDate,
            location: best.location
        )
    }

    private func overlapDuration(_ event: EKEvent, _ interval: DateInterval) -> TimeInterval {
        guard event.startDate <= event.endDate else { return 0 }
        let eventInterval = DateInterval(start: event.startDate, end: event.endDate)
        return eventInterval.intersection(with: interval)?.duration ?? 0
    }

    private func requestAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToEvents()) ?? false
    }
}

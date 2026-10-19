import Foundation

/// The calendar event (if any) a recording overlapped with. Inert data —
/// see ARCHITECTURE.md's "The pattern" section.
public struct CalendarContext: Codable, Equatable, Sendable {
    public let eventTitle: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?

    public init(eventTitle: String, startDate: Date, endDate: Date, location: String? = nil) {
        self.eventTitle = eventTitle
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
    }
}

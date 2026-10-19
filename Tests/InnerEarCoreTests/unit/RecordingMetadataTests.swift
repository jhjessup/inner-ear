import Foundation
import Testing
@testable import InnerEarMetadata

/// Pure `Codable` round-trip tests for the metadata models — no
/// filesystem. See `MetadataStoreTests` for the real-persistence
/// equivalent.
struct RecordingMetadataTests {

    @Test
    func recordingMetadata_encodeDecode_roundTripsWithBothContextsPresent() throws {
        let metadata = RecordingMetadata(
            recordingID: UUID(),
            calendarContext: CalendarContext(
                eventTitle: "Design Review",
                startDate: Date(timeIntervalSince1970: 1_000_000),
                endDate: Date(timeIntervalSince1970: 1_003_600),
                location: "Zoom"
            ),
            windowContext: WindowContext(
                applicationName: "zoom.us",
                windowTitle: "Design Review — Zoom",
                capturedAt: Date(timeIntervalSince1970: 1_000_500)
            ),
            capturedAt: Date(timeIntervalSince1970: 1_000_500)
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: data)

        #expect(decoded == metadata)
    }

    @Test
    func recordingMetadata_encodeDecode_roundTripsWithBothContextsNil() throws {
        let metadata = RecordingMetadata(
            recordingID: UUID(),
            calendarContext: nil,
            windowContext: nil,
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: data)

        #expect(decoded == metadata)
        #expect(decoded.calendarContext == nil)
        #expect(decoded.windowContext == nil)
    }
}

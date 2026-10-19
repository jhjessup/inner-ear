import Foundation
import Testing
import InnerEarCore
@testable import InnerEarMetadata

/// Tests for `MetadataStore` — save/load round-trip and list ordering.
/// Nested under `DataDirectoryTests` for the same reason as
/// `RecordingStoreTests`/`TranscriptStoreTests` — see that type's doc
/// comment (shared process-wide `INNEREAR_DATA_DIR` env var).
extension DataDirectoryTests {

@Suite(.serialized)
struct MetadataStoreTests {

    private func makeStore() throws -> MetadataStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("innerear-metadata-store-tests-\(UUID().uuidString)", isDirectory: true)
        setenv("INNEREAR_DATA_DIR", tempDir.path, 1)
        return try MetadataStore()
    }

    private func makeMetadata(
        recordingID: UUID = UUID(),
        capturedAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> RecordingMetadata {
        RecordingMetadata(
            recordingID: recordingID,
            calendarContext: CalendarContext(
                eventTitle: "Standup",
                startDate: Date(timeIntervalSince1970: 999_000),
                endDate: Date(timeIntervalSince1970: 1_001_000)
            ),
            windowContext: WindowContext(
                applicationName: "zoom.us",
                windowTitle: "Zoom Meeting",
                capturedAt: capturedAt
            ),
            capturedAt: capturedAt
        )
    }

    @Test
    func saveMetadata_thenListAll_returnsEquivalentEntry() throws {
        let store = try makeStore()
        let metadata = makeMetadata()

        try store.save(metadata)
        let listed = try store.listAll()

        #expect(listed.count == 1)
        #expect(listed.first == metadata)
    }

    @Test
    func listAll_returnsMostRecentlyCapturedFirst() throws {
        let store = try makeStore()
        let older = makeMetadata(capturedAt: Date(timeIntervalSince1970: 1_000_000))
        let newer = makeMetadata(capturedAt: Date(timeIntervalSince1970: 2_000_000))

        try store.save(older)
        try store.save(newer)

        let listed = try store.listAll()

        #expect(listed.map(\.id) == [newer.id, older.id])
    }

    @Test
    func saveMetadata_withNilCalendarContext_roundTripsNilCorrectly() throws {
        let store = try makeStore()
        let metadata = RecordingMetadata(
            recordingID: UUID(),
            calendarContext: nil,
            windowContext: WindowContext(applicationName: "Terminal", windowTitle: nil, capturedAt: Date(timeIntervalSince1970: 0)),
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        try store.save(metadata)
        let listed = try store.listAll()

        #expect(listed.first?.calendarContext == nil)
        #expect(listed.first?.windowContext?.windowTitle == nil)
    }
}

}

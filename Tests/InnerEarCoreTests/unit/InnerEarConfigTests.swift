import Foundation
import Testing
@testable import InnerEarCore

/// Pure `Codable` round-trip tests for `InnerEarConfig`/`TranscriptionMode`
/// — no filesystem, no environment variables. See
/// `InnerEarConfigResolverTests`'s doc comment for why the config-FILE-
/// driven resolution path (reading/writing `config.json` on disk) isn't
/// exercised hermetically yet — same gap applies to
/// `resolveTranscriptionMode`/`writeTranscriptionMode`, which both always
/// target the fixed default Application Support location.
struct InnerEarConfigTests {

    @Test
    func encodeDecode_roundTripsAllFields() throws {
        let config = InnerEarConfig(recordingsDirectory: "/tmp/custom", transcriptionMode: .automatic)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(InnerEarConfig.self, from: data)

        #expect(decoded.recordingsDirectory == "/tmp/custom")
        #expect(decoded.transcriptionMode == .automatic)
    }

    @Test
    func decode_missingTranscriptionModeKey_defaultsToNil() throws {
        // Simulates an existing config.json written before this field
        // existed — must decode without throwing, with transcriptionMode
        // nil (which InnerEarConfigResolver.resolveTranscriptionMode then
        // maps to `.manual`, this app's original always-manual behavior).
        let legacyJSON = #"{"recordingsDirectory":"/tmp/custom"}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(InnerEarConfig.self, from: legacyJSON)

        #expect(decoded.recordingsDirectory == "/tmp/custom")
        #expect(decoded.transcriptionMode == nil)
    }

    @Test
    func transcriptionMode_rawValues_matchExpectedStrings() {
        // Pins the on-disk string representation — changing these would
        // silently break decoding of an already-written config.json.
        #expect(TranscriptionMode.disabled.rawValue == "disabled")
        #expect(TranscriptionMode.manual.rawValue == "manual")
        #expect(TranscriptionMode.automatic.rawValue == "automatic")
    }
}

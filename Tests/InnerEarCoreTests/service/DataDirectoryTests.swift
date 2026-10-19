import Testing

/// Umbrella suite for every test that mutates the process-wide
/// `INNEREAR_DATA_DIR` environment variable to point `RecordingStore`/
/// `TranscriptStore` at a hermetic temp directory (see those types' own
/// doc comments for why they read the real environment rather than
/// accepting an injectable override).
///
/// Swift Testing's `.serialized` trait only serializes tests *within* the
/// suite it's applied to — it does NOT serialize across separate top-level
/// suites. `RecordingStoreTests`, `TranscriptStoreTests`, and
/// `RecordingDeletionIntegrationTests` each independently call `setenv`,
/// so without nesting them under one serialized parent, Swift Testing can
/// run them concurrently and race on that shared env var: one suite's
/// `setenv` can clobber another's between its `setenv` call and the
/// `RecordingStore()`/`TranscriptStore()` init that reads it a few lines
/// later. Observed in practice as an intermittent
/// `RecordingDeletionIntegrationTests` failure. Nesting all three here
/// makes Swift Testing run the whole subtree one test at a time.
@Suite(.serialized)
struct DataDirectoryTests {}

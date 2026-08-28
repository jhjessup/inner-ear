import Foundation

/// User-tunable configuration for the InnerEar data directory.
///
/// The `recordingsDirectory` field lets a user point InnerEar's storage
/// somewhere other than the default `~/Library/Application Support/InnerEar/`
/// — useful for syncing recordings to iCloud/Dropbox, working on a project
/// from a custom mount, or running multiple test instances side-by-side.
///
/// Today this struct only carries `recordingsDirectory`; future
/// configuration knobs (e.g. a transcription model preference) belong here too.
public struct InnerEarConfig: Codable, Sendable {
    /// Absolute (or `~`-prefixed) filesystem path under which InnerEar
    /// should write its `recordings/`, `transcripts/`, and `summaries/`
    /// subdirectories. `nil` or empty means "use the default Application
    /// Support location".
    public var recordingsDirectory: String?

    public init(recordingsDirectory: String? = nil) {
        self.recordingsDirectory = recordingsDirectory
    }
}

/// Resolves the on-disk directory InnerEar should use for its data
/// (recordings, transcripts, summaries, and — importantly — its own
/// `config.json`).
///
/// The precedence, highest to lowest, is:
///   1. The `INNEREAR_DATA_DIR` environment variable, if present and
///      non-empty. Tilde (`~`) is expanded.
///   2. A JSON config file at `<default app support>/InnerEar/config.json`
///      whose `recordingsDirectory` field is present and non-empty.
///      Tilde is expanded. (Note: the config file ITSELF always lives
///      at the default location from case 3, regardless of what
///      `recordingsDirectory` it points to — this avoids the chicken-and-
///      egg problem where redirecting storage would also hide the config
///      that did the redirecting.)
///   3. The fixed default: `<Application Support>/InnerEar/`.
///
/// The `environment` and `fileManager` parameters exist so this function
/// is unit-testable without mutating the real process environment or
/// touching the real filesystem: a test can pass a custom dictionary for
/// `environment`. The config-file-reading path currently still uses
/// `FileManager.default` and `NSSearchPathForDirectoriesInDomains` to find
/// the canonical Application Support directory — fully faking those
/// across all relevant call sites is significant scaffolding for limited
/// test value, and the env-var-driven path (the only one commonly
/// exercised in CI) is fully testable. The `fileManager` parameter is
/// accepted today for future extensibility; if/when config-file-present
/// test cases need to be hermetic, that path can be retrofitted to
/// thread `fileManager` through without changing this signature.
public enum InnerEarConfigResolver {
    public static func resolveDataDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        // Case 1: env var wins.
        if let envPath = environment["INNEREAR_DATA_DIR"],
           !envPath.isEmpty {
            return URL(fileURLWithPath: expandTilde(envPath))
        }

        // Case 3 (computed up front, since the config file lives here regardless
        // of what `recordingsDirectory` ends up pointing at): the default
        // Application Support / InnerEar/ base directory.
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let defaultBase = appSupport.appendingPathComponent("InnerEar", isDirectory: true)

        // Case 2: config file at the fixed default location, if it exists
        // and decodes to a non-empty `recordingsDirectory`.
        let configURL = defaultBase.appendingPathComponent("config.json", isDirectory: false)
        if fileManager.fileExists(atPath: configURL.path),
           let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(InnerEarConfig.self, from: data),
           let configured = config.recordingsDirectory,
           !configured.isEmpty {
            return URL(fileURLWithPath: expandTilde(configured))
        }

        // Case 3: fall back to the default base directory.
        return defaultBase
    }

    /// Expand a leading `~` to the current user's home directory. Other
    /// forms like `~user/...` are NOT supported — InnerEar only ever
    /// writes as the current user.
    private static func expandTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}

import Foundation
import Testing
@testable import InnerEarCore

/// Tests for `InnerEarConfigResolver.resolveDataDirectory(environment:fileManager:)`.
///
/// Focuses on the two precedence rules that are fully hermetic to test:
///   - the `INNEREAR_DATA_DIR` env-var path (case 1), and
///   - the default-fallback path (case 3) when the env var is absent.
///
/// The config-file-driven case (case 2) is intentionally not exercised here:
/// it requires writing a real `config.json` to the user's Application Support
/// directory, which would mutate global state on the host running tests.
/// The resolver is structured so that case 2 only activates after case 1
/// falls through, which is the property the env-var tests already cover.
struct InnerEarConfigResolverTests {

    // MARK: - Case 1: INNEREAR_DATA_DIR wins

    @Test
    func resolveDataDirectory_whenEnvVarSet_usesItDirectly() {
        // An absolute path with no tilde — should be used verbatim.
        let env = ["INNEREAR_DATA_DIR": "/tmp/innerear-custom"]
        let resolved = InnerEarConfigResolver.resolveDataDirectory(environment: env)

        #expect(resolved.path == "/tmp/innerear-custom")
    }

    @Test
    func resolveDataDirectory_whenEnvVarSetWithTilde_expandsTilde() {
        // `~`-prefixed paths must be expanded to the actual home directory,
        // not passed through with a literal `~` character in them.
        let env = ["INNEREAR_DATA_DIR": "~/innerear-tilde-test"]
        let resolved = InnerEarConfigResolver.resolveDataDirectory(environment: env)

        // The resolved path must not contain a literal tilde.
        #expect(!resolved.path.contains("~"))
        // And it must end with the trailing component we specified, so the
        // expansion actually worked rather than collapsing to `~` → home
        // without appending our suffix.
        #expect(resolved.path.hasSuffix("/innerear-tilde-test"))
    }

    @Test
    func resolveDataDirectory_whenEnvVarSetWinsOverDefault() {
        // Sanity-check the precedence: env var should NOT fall through to
        // the Application-Support-based default even if the env value is
        // a path the default would never produce.
        let env = ["INNEREAR_DATA_DIR": "/var/tmp/innerear-precedence-check"]
        let resolved = InnerEarConfigResolver.resolveDataDirectory(environment: env)

        // Application Support under the user domain typically lives
        // under `/Users/<user>/Library/Application Support` on macOS —
        // our custom env value should not match that pattern.
        #expect(resolved.path == "/var/tmp/innerear-precedence-check")
        #expect(!resolved.path.contains("Library/Application Support"))
    }

    // MARK: - Case 3: no env var → default Application-Support-based path

    @Test
    func resolveDataDirectory_whenEnvVarAbsent_fallsBackToDefault() {
        // Empty environment dictionary → env-var path is skipped entirely.
        let resolved = InnerEarConfigResolver.resolveDataDirectory(environment: [:])

        // The default case appends an "InnerEar" component to the user's
        // Application Support directory. Asserting on the last path
        // component (rather than the full absolute path, which depends on
        // the user) is robust across hosts.
        #expect(resolved.lastPathComponent == "InnerEar")
    }

    @Test
    func resolveDataDirectory_whenEnvVarIsEmptyString_fallsBackToDefault() {
        // An explicitly-empty env value should be treated the same as a
        // missing one: empty string is "not set" per the resolver's spec.
        let env = ["INNEREAR_DATA_DIR": ""]
        let resolved = InnerEarConfigResolver.resolveDataDirectory(environment: env)

        #expect(resolved.lastPathComponent == "InnerEar")
    }
}

import Foundation

/// Captures a snapshot of whichever window currently has focus.
public protocol WindowMetadataService: AnyObject, Sendable {
    /// `nil` only when no frontmost application can be determined at all
    /// (practically never on a real session) — a window whose TITLE can't
    /// be read (e.g. missing Screen Recording permission) still returns a
    /// `WindowContext` with `windowTitle: nil`, not `nil` itself.
    func captureForegroundWindow() async -> WindowContext?
}

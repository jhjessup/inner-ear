import Foundation
import AppKit
import CoreGraphics

/// Real `WindowMetadataService` backed by `NSWorkspace` (frontmost app) and
/// `CGWindowListCopyWindowInfo` (window title). Fully local — no network
/// access.
///
/// The application name comes from `NSWorkspace.frontmostApplication`,
/// which needs no special permission. The window TITLE needs Screen
/// Recording permission on modern macOS — the SAME permission
/// `AVFoundationAudioCaptureService` already requests for system-audio
/// capture (see `setupSystemAudioCapture`), so a user who's granted that
/// already gets window titles here for free; one who hasn't still gets the
/// application name, just not the title.
public final class CGWindowListWindowMetadataService: WindowMetadataService, @unchecked Sendable {
    public init() {}

    public func captureForegroundWindow() async -> WindowContext? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = frontApp.localizedName ?? "Unknown"
        let title = windowTitle(forProcessID: frontApp.processIdentifier)
        return WindowContext(applicationName: appName, windowTitle: title, capturedAt: Date())
    }

    /// Looks up the on-screen window title owned by `pid`, if
    /// `CGWindowListCopyWindowInfo` can see it (requires Screen Recording
    /// permission for the title to be populated; without it, `kCGWindowName`
    /// is silently omitted rather than the call failing outright).
    private func windowTitle(forProcessID pid: pid_t) -> String? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: AnyObject]] else {
            return nil
        }

        return windowList.first { info in
            (info[kCGWindowOwnerPID as String] as? pid_t) == pid
        }?[kCGWindowName as String] as? String
    }
}

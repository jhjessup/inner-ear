import Foundation

/// A snapshot of whichever application/window had focus at the moment it
/// was captured. Inert data — see ARCHITECTURE.md's "The pattern" section.
public struct WindowContext: Codable, Equatable, Sendable {
    public let applicationName: String
    /// `nil` when the window's title couldn't be read — e.g. Screen
    /// Recording permission hasn't been granted (the same permission
    /// system-audio capture already requires; see
    /// `CGWindowListWindowMetadataService`). The application name is still
    /// available without that permission.
    public let windowTitle: String?
    public let capturedAt: Date

    public init(applicationName: String, windowTitle: String?, capturedAt: Date) {
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.capturedAt = capturedAt
    }
}

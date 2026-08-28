import Foundation

/// Events that drive the TUI state machine.
///
/// - `key`: A single character from the raw terminal input (e.g. '1', 'j', 'q').
/// - `tick`: A periodic clock event (currently unused by `reduce`, but
///   reserved for future animations or auto-refresh without a keypress).
public enum TUIEvent: Equatable, Sendable {
    case key(Character)
    case tick(Date)
}
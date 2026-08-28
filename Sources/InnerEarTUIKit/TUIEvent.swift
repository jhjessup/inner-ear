import Foundation

public enum TUIEvent: Equatable, Sendable {
    case key(Character)
    case tick(Date)
}

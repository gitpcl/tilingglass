import KeyboardShortcuts
import TilingCore

extension KeyboardShortcuts.Name {
    static let moveTileLeft = Self("moveTileLeft", default: .init(.leftArrow, modifiers: [.command, .option]))
    static let moveTileRight = Self("moveTileRight", default: .init(.rightArrow, modifiers: [.command, .option]))
    static let moveTileUp = Self("moveTileUp", default: .init(.upArrow, modifiers: [.command, .option]))
    static let moveTileDown = Self("moveTileDown", default: .init(.downArrow, modifiers: [.command, .option]))
}

/// Registers the global keyboard shortcuts for moving the focused window between
/// zones. Backed by the KeyboardShortcuts library, which handles persistence,
/// the recorder UI, and conflict detection.
@MainActor
final class HotkeyManager {
    private let engine: TilingEngine

    init(engine: TilingEngine) {
        self.engine = engine
    }

    func register() {
        KeyboardShortcuts.onKeyDown(for: .moveTileLeft) { [engine] in engine.moveFocused(.left) }
        KeyboardShortcuts.onKeyDown(for: .moveTileRight) { [engine] in engine.moveFocused(.right) }
        KeyboardShortcuts.onKeyDown(for: .moveTileUp) { [engine] in engine.moveFocused(.up) }
        KeyboardShortcuts.onKeyDown(for: .moveTileDown) { [engine] in engine.moveFocused(.down) }
    }
}

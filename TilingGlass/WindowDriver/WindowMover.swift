import CoreGraphics

/// Moves and resizes windows via the Accessibility API. Encapsulates the quirks
/// that make this reliable across apps.
@MainActor
enum WindowMover {
    enum Result: Equatable {
        /// The window landed at the requested frame (within tolerance).
        case full
        /// The window moved but clamped to a different size (e.g. a minimum
        /// size). Its top-left is still correct. `actual` is the resulting frame.
        case partial(actual: CGRect)
        /// The window could not be positioned at all.
        case failed
    }

    private static let sizeTolerance: CGFloat = 2

    /// Moves `window` to `targetFrame` (AX/top-left coordinates).
    ///
    /// The sequence sets size → position → size again: a position set can be
    /// clamped by the current size and vice-versa, so doing both twice lands the
    /// window reliably. `AXEnhancedUserInterface` is cleared around the move
    /// because, while enabled, Chromium/Electron apps ignore position changes.
    @discardableResult
    static func move(_ window: AccessibilityElement, to targetFrame: CGRect) -> Result {
        guard window.isPositionSettable || window.isSizeSettable else {
            return .failed
        }

        let app = window.owningApplication()
        let hadEnhancedUI = app?.isEnhancedUserInterfaceEnabled ?? false
        if hadEnhancedUI { app?.setEnhancedUserInterface(false) }
        defer { if hadEnhancedUI { app?.setEnhancedUserInterface(true) } }

        window.setSize(targetFrame.size)
        window.setPosition(targetFrame.origin)
        window.setSize(targetFrame.size)

        guard let resulting = window.frame else {
            // Position was set but we can't read back — assume it took.
            return .full
        }

        let widthOff = abs(resulting.width - targetFrame.width)
        let heightOff = abs(resulting.height - targetFrame.height)
        if widthOff <= sizeTolerance && heightOff <= sizeTolerance {
            return .full
        }
        return .partial(actual: resulting)
    }
}

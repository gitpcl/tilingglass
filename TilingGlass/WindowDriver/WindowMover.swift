// SPDX-License-Identifier: GPL-3.0-only

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

        // Report `.full` only if both size and position landed. Some apps clamp
        // a minimum size or refuse to move outside the visible area; those are
        // `.partial` so callers/logging don't over-report success.
        let sizeOff = max(abs(resulting.width - targetFrame.width), abs(resulting.height - targetFrame.height))
        let positionOff = max(abs(resulting.minX - targetFrame.minX), abs(resulting.minY - targetFrame.minY))
        if sizeOff <= sizeTolerance && positionOff <= sizeTolerance {
            return .full
        }
        return .partial(actual: resulting)
    }
}

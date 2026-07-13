// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// The single place where TilingGlass converts between the two coordinate
/// spaces macOS exposes:
///
/// - **AppKit** (`NSScreen`, `NSWindow`, `NSEvent.mouseLocation`): origin at the
///   bottom-left of the primary screen, y increases upward.
/// - **Accessibility / CoreGraphics global** (`kAXPositionAttribute`,
///   `CGEvent`): origin at the top-left of the primary screen, y increases
///   downward.
///
/// Keeping every flip here (and exhaustively unit-testing it) means the rest of
/// the app can reason in a single space without scattering `height - y`
/// arithmetic through the codebase.
public enum CoordinateConversion {
    /// Flips a point between AppKit (bottom-left) and CG/AX (top-left) space.
    ///
    /// The transform is its own inverse, so the same function converts in both
    /// directions given the primary screen's height.
    public static func flipY(_ point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// Converts an AppKit rect (bottom-left origin) to a CG/AX rect (top-left origin).
    ///
    /// The rect's own height is subtracted because a rect's origin is its
    /// bottom-left corner in AppKit but its top-left corner in AX.
    public static func axRect(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Converts a CG/AX rect (top-left origin) back to an AppKit rect (bottom-left origin).
    ///
    /// Symmetric with ``axRect(fromAppKit:primaryScreenHeight:)``.
    public static func appKitRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

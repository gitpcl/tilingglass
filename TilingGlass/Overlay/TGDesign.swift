// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

/// Shared visual constants for TilingGlass's spatial surfaces — the drag overlay
/// today, the layout editor next. Centralizing corner radii, motion, and glass
/// accents keeps those surfaces speaking one visual language instead of each
/// re-inventing magic numbers.
enum TGDesign {
    /// Corner radius for zone tiles in the drag overlay.
    static let zoneCorner: CGFloat = 14

    /// Spring for a zone's highlight state changing — quick, but enough of a
    /// settle that the highlight reads as physical rather than a hard cut.
    static let highlightSpring = Animation.spring(response: 0.22, dampingFraction: 0.86)

    /// Spring that materializes / dissolves the whole overlay.
    static let overlaySpring = Animation.spring(response: 0.28, dampingFraction: 0.82)

    /// Reduced-motion replacement for the overlay spring: an opacity-only near-snap.
    static let overlayReducedMotion = Animation.easeOut(duration: 0.08)

    /// How long the overlay's dissolve runs before its panels are torn down.
    /// Kept comfortably past the overlay spring's visual settle so a panel is
    /// fully faded before it closes.
    static let overlayFadeDuration = Duration.milliseconds(350)

    /// Scale a zone grows to while highlighted, so the active zone reads as
    /// lifting slightly toward the cursor.
    static let highlightScale: CGFloat = 1.02

    /// Idle (non-highlighted) zone stroke.
    static let idleStroke = Color.white.opacity(0.45)

    /// Glass tint opacity for a single hovered zone vs. a multi-zone span. The
    /// span is stronger so a merged selection reads as more committed without
    /// inventing a non-system hue.
    static let singleTintOpacity = 0.5
    static let spanTintOpacity = 0.72
}

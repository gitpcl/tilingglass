// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Inner and outer spacing applied when resolving tiles to pixel rects.
public struct Gaps: Equatable, Sendable {
    /// Total spacing between two adjacent tiles. Each tile is inset by half of
    /// this on a shared edge so the visible gap between them equals `inner`.
    public var inner: CGFloat
    /// Spacing between a tile and the screen edge it touches.
    public var outer: CGFloat

    public init(inner: CGFloat, outer: CGFloat) {
        // Negative gaps would expand tiles past their zone (or into each other)
        // in ways nothing downstream expects; clamp at the boundary.
        self.inner = max(0, inner)
        self.outer = max(0, outer)
    }

    public static let zero = Gaps(inner: 0, outer: 0)
}

/// Converts normalized tiles (0...1 space, top-left origin) into concrete pixel
/// rects within a screen's usable area, applying gap rules.
///
/// **Coordinate space:** a tile's `y` is measured from the *top*, so
/// `screenRect` must be a top-left/y-down rect (i.e. AX/CG space). Passing an
/// AppKit (bottom-left/y-up) rect mirrors the result vertically. `x`/width are
/// unaffected by orientation. The result is returned in the same space as
/// `screenRect`.
public enum ZoneGeometry {
    private static let edgeTolerance = 1e-6

    /// Resolves a single tile to a pixel rect within `screenRect`, applying gaps.
    public static func resolve(_ tile: Tile, in screenRect: CGRect, gaps: Gaps) -> CGRect {
        resolve(
            normalizedX: tile.x, y: tile.y, width: tile.width, height: tile.height,
            in: screenRect, gaps: gaps
        )
    }

    /// Resolves an arbitrary normalized rect (e.g. the bounding rect of a
    /// multi-tile span selection) to a pixel rect, applying gaps.
    public static func resolve(normalizedRect rect: CGRect, in screenRect: CGRect, gaps: Gaps) -> CGRect {
        resolve(
            normalizedX: rect.minX, y: rect.minY, width: rect.width, height: rect.height,
            in: screenRect, gaps: gaps
        )
    }

    private static func resolve(
        normalizedX nx: Double, y ny: Double, width nw: Double, height nh: Double,
        in screenRect: CGRect, gaps: Gaps
    ) -> CGRect {
        // Scale the normalized rect into the screen's pixel space.
        let px = screenRect.minX + CGFloat(nx) * screenRect.width
        let py = screenRect.minY + CGFloat(ny) * screenRect.height
        let pw = CGFloat(nw) * screenRect.width
        let ph = CGFloat(nh) * screenRect.height

        // Each edge gets the outer gap if it sits on the screen boundary,
        // otherwise half the inner gap (the neighbouring tile supplies the
        // other half).
        let leftInset = inset(atFraction: nx, boundary: 0, gaps: gaps)
        let topInset = inset(atFraction: ny, boundary: 0, gaps: gaps)
        let rightInset = inset(atFraction: nx + nw, boundary: 1, gaps: gaps)
        let bottomInset = inset(atFraction: ny + nh, boundary: 1, gaps: gaps)

        // Computed on the *signed* raw values, not `CGRect.width`/`.height` —
        // those getters return the absolute value, which would silently defeat
        // the floor below whenever gaps exceed the tile's own pixel size.
        let rawWidth = pw - leftInset - rightInset
        let rawHeight = ph - topInset - bottomInset
        let width = max(1, rawWidth)
        let height = max(1, rawHeight)

        // Guard against pathological gap/screen combinations collapsing (or
        // inverting) a tile. In the normal case the raw size is already >= 1 and
        // these branches are no-ops; only when gaps exceed the tile's pixel size
        // do we fall back to a minimal rect centered on the tile's own pixel
        // footprint, rather than one offset by the (now meaningless) insets.
        let x = rawWidth >= 1 ? px + leftInset : px + (pw - width) / 2
        let y = rawHeight >= 1 ? py + topInset : py + (ph - height) / 2

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func inset(atFraction fraction: Double, boundary: Double, gaps: Gaps) -> CGFloat {
        abs(fraction - boundary) < edgeTolerance ? gaps.outer : gaps.inner / 2
    }
}

// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Pure geometry for deciding which tile the cursor is over and, when the span
/// modifier is held, which set of tiles a drag currently covers.
public enum ZoneHitTesting {
    private static let overlapTolerance = 1e-6

    /// The tile's rect in normalized (0...1, top-left origin) space.
    public static func normalizedRect(of tile: Tile) -> CGRect {
        CGRect(x: tile.x, y: tile.y, width: tile.width, height: tile.height)
    }

    /// Returns the index of the tile containing `point`, or `nil` if none does.
    ///
    /// Hit-testing uses the full (ungapped) tile areas so the gap regions
    /// between tiles still resolve to their owning zone. `point` and
    /// `screenRect` must be in the same coordinate space. The far screen edge is
    /// treated as inside (unlike `CGRect.contains`).
    ///
    /// Tile bounds are inclusive on all sides and tiles are tested in layout
    /// order, so a point exactly on a shared edge resolves to the earlier tile.
    public static func tileIndex(at point: CGPoint, layout: Layout, screenRect: CGRect) -> Int? {
        guard screenRect.width > 0, screenRect.height > 0 else { return nil }

        // Normalize the point into 0...1 space relative to the screen.
        let nx = Double((point.x - screenRect.minX) / screenRect.width)
        let ny = Double((point.y - screenRect.minY) / screenRect.height)
        guard nx >= -overlapTolerance, nx <= 1 + overlapTolerance,
              ny >= -overlapTolerance, ny <= 1 + overlapTolerance else { return nil }

        for (index, tile) in layout.tiles.enumerated() {
            let onX = nx >= tile.x - overlapTolerance && nx <= tile.maxX + overlapTolerance
            let onY = ny >= tile.y - overlapTolerance && ny <= tile.maxY + overlapTolerance
            if onX && onY { return index }
        }
        return nil
    }

    /// Given an anchor tile and the currently hovered tile, returns the set of
    /// tile indices covered by their span.
    ///
    /// Matches Tiling Shell: the covered set is every tile intersecting the
    /// bounding rect of the anchor and hovered tiles.
    public static func spanSelection(anchor: Int, hovered: Int, layout: Layout) -> Set<Int> {
        let tiles = layout.tiles
        guard tiles.indices.contains(anchor), tiles.indices.contains(hovered) else {
            return []
        }
        let union = normalizedRect(of: tiles[anchor]).union(normalizedRect(of: tiles[hovered]))

        var selection = Set<Int>()
        for (index, tile) in tiles.enumerated() {
            let intersection = normalizedRect(of: tile).intersection(union)
            if intersection.width > overlapTolerance && intersection.height > overlapTolerance {
                selection.insert(index)
            }
        }
        return selection
    }

    /// The normalized bounding rect covering all tiles in `selection` — i.e. the
    /// area a spanning window should fill.
    public static func targetNormalizedRect(for selection: Set<Int>, layout: Layout) -> CGRect? {
        let rects = selection
            .filter { layout.tiles.indices.contains($0) }
            .map { normalizedRect(of: layout.tiles[$0]) }
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }
}

// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// How a tile is divided in two by the editor.
public enum SplitOrientation: Sendable {
    /// Side-by-side halves (a vertical cut line): the tiles end up arranged
    /// horizontally, matching Tiling Shell's "left click splits horizontally".
    case horizontal
    /// Stacked halves (a horizontal cut line): top/bottom.
    case vertical
}

/// An internal edge segment between adjacent tiles, as grabbed by the editor
/// for dragging. Positions are in normalized (0...1, top-left origin) space.
public struct LayoutBoundary: Equatable, Sendable {
    public enum Orientation: Sendable {
        /// A vertical line (constant x); dragging moves it left/right.
        case vertical
        /// A horizontal line (constant y); dragging moves it up/down.
        case horizontal
    }

    public let orientation: Orientation
    /// The line's coordinate: x for vertical boundaries, y for horizontal.
    public let position: Double
    /// Indices of tiles ending at the boundary (left of a vertical line, above
    /// a horizontal one).
    public let leadingTiles: [Int]
    /// Indices of tiles starting at the boundary (right of a vertical line,
    /// below a horizontal one).
    public let trailingTiles: [Int]
}

/// Pure editing operations for the layout editor. Every operation returns a new
/// layout; tile `groups` are treated as stale during editing and recomputed
/// once on save via ``recomputingGroups(_:)``.
public enum LayoutEditing {
    private static let epsilon = 1e-6

    // MARK: - Splitting

    /// Splits the tile at `index` into two equal halves. Returns the layout
    /// unchanged if `index` is out of range.
    ///
    /// The two halves replace the original at the same position in the tile
    /// array (first the leading/top half, then the trailing/bottom half).
    public static func splitting(_ layout: Layout, tileAt index: Int, _ orientation: SplitOrientation) -> Layout {
        guard layout.tiles.indices.contains(index) else { return layout }
        let tile = layout.tiles[index]

        let first: Tile
        let second: Tile
        switch orientation {
        case .horizontal:
            let half = tile.width / 2
            first = Tile(x: tile.x, y: tile.y, width: half, height: tile.height)
            second = Tile(x: tile.x + half, y: tile.y, width: half, height: tile.height)
        case .vertical:
            let half = tile.height / 2
            first = Tile(x: tile.x, y: tile.y, width: tile.width, height: half)
            second = Tile(x: tile.x, y: tile.y + half, width: tile.width, height: half)
        }

        var tiles = layout.tiles
        tiles.replaceSubrange(index...index, with: [first, second])
        return Layout(id: layout.id, tiles: tiles)
    }

    // MARK: - Removing

    /// Removes the tile at `index`, expanding a neighbor to absorb its space.
    ///
    /// A neighbor can absorb the removed tile only when the two share a *full*
    /// edge (equal cross-axis position and extent) — that's the only case where
    /// the union of the two rects is itself a rect. Horizontal neighbors are
    /// preferred over vertical ones. Returns `nil` when no neighbor qualifies
    /// or the layout has only one tile — the caller should leave the layout
    /// unchanged rather than create a hole.
    public static func removing(_ layout: Layout, tileAt index: Int) -> Layout? {
        guard layout.tiles.indices.contains(index), layout.tiles.count > 1 else { return nil }
        let removed = layout.tiles[index]

        func fullVerticalEdgeMatch(_ candidate: Tile) -> Bool {
            nearly(candidate.y, removed.y) && nearly(candidate.height, removed.height)
        }
        func fullHorizontalEdgeMatch(_ candidate: Tile) -> Bool {
            nearly(candidate.x, removed.x) && nearly(candidate.width, removed.width)
        }

        for (candidateIndex, candidate) in layout.tiles.enumerated() where candidateIndex != index {
            var merged: Tile?
            if nearly(candidate.maxX, removed.x), fullVerticalEdgeMatch(candidate) {
                // Neighbor on the left absorbs rightward.
                merged = Tile(x: candidate.x, y: candidate.y, width: candidate.width + removed.width, height: candidate.height, groups: candidate.groups)
            } else if nearly(removed.maxX, candidate.x), fullVerticalEdgeMatch(candidate) {
                // Neighbor on the right absorbs leftward.
                merged = Tile(x: removed.x, y: candidate.y, width: candidate.width + removed.width, height: candidate.height, groups: candidate.groups)
            } else if nearly(candidate.maxY, removed.y), fullHorizontalEdgeMatch(candidate) {
                // Neighbor above absorbs downward.
                merged = Tile(x: candidate.x, y: candidate.y, width: candidate.width, height: candidate.height + removed.height, groups: candidate.groups)
            } else if nearly(removed.maxY, candidate.y), fullHorizontalEdgeMatch(candidate) {
                // Neighbor below absorbs upward.
                merged = Tile(x: candidate.x, y: removed.y, width: candidate.width, height: candidate.height + removed.height, groups: candidate.groups)
            }

            if let merged {
                var tiles = layout.tiles
                tiles[candidateIndex] = merged
                tiles.remove(at: index)
                return Layout(id: layout.id, tiles: tiles)
            }
        }
        return nil
    }

    // MARK: - Boundaries

    /// Finds the internal boundary segment within `tolerance` of `point`, if
    /// any. Screen edges (0 and 1) are never boundaries. When the point is near
    /// both a vertical and a horizontal boundary (a corner), the nearer wins.
    public static func boundary(near point: CGPoint, in layout: Layout, tolerance: Double) -> LayoutBoundary? {
        var best: (boundary: LayoutBoundary, distance: Double)?

        for tile in layout.tiles {
            // Candidate vertical lines: this tile's right edge; horizontal:
            // its bottom edge. (Left/top edges are some other tile's right/
            // bottom, or the screen edge — no need to consider them twice.)
            for (orientation, linePosition, crossRange) in [
                (LayoutBoundary.Orientation.vertical, tile.maxX, tile.y...(tile.maxY)),
                (LayoutBoundary.Orientation.horizontal, tile.maxY, tile.x...(tile.maxX)),
            ] {
                // Screen edges are not draggable boundaries.
                if linePosition < epsilon || linePosition > 1 - epsilon { continue }

                let (along, across) = orientation == .vertical
                    ? (Double(point.y), Double(point.x))
                    : (Double(point.x), Double(point.y))
                guard crossRange.contains(along) else { continue }
                let distance = abs(across - linePosition)
                guard distance <= tolerance else { continue }

                guard let boundary = makeBoundary(
                    orientation: orientation, position: linePosition, at: along, in: layout
                ) else { continue }

                if best == nil || distance < best!.distance {
                    best = (boundary, distance)
                }
            }
        }
        return best?.boundary
    }

    /// Builds the boundary at (`orientation`, `position`) grabbed at the
    /// cross-axis coordinate `along`.
    ///
    /// Starts from the tiles directly under the grab point (one pair required),
    /// then expands by transitive closure: a tile is a single rectangle with a
    /// single edge, so when it moves, every tile bordering the line whose
    /// extent overlaps an already-affected tile's extent must move with it —
    /// otherwise the layout tears into gaps or overlaps. Segments that aren't
    /// chained stay independent: in a 2x2 grid, grabbing the mid-line in the
    /// top half still drags just the top pair (the bottom pair only *touches*
    /// the top tiles at a point, which doesn't chain). But a full-height tile
    /// bordering two stacked tiles chains all three, so the whole line moves.
    private static func makeBoundary(
        orientation: LayoutBoundary.Orientation, position: Double, at along: Double, in layout: Layout
    ) -> LayoutBoundary? {
        struct Borderer {
            let tileIndex: Int
            let isLeading: Bool
            let range: ClosedRange<Double>
        }

        var borderers: [Borderer] = []
        for (index, tile) in layout.tiles.enumerated() {
            let (start, end, range): (Double, Double, ClosedRange<Double>)
            switch orientation {
            case .vertical:
                (start, end, range) = (tile.x, tile.maxX, tile.y...tile.maxY)
            case .horizontal:
                (start, end, range) = (tile.y, tile.maxY, tile.x...tile.maxX)
            }
            if nearly(end, position) {
                borderers.append(Borderer(tileIndex: index, isLeading: true, range: range))
            } else if nearly(start, position) {
                borderers.append(Borderer(tileIndex: index, isLeading: false, range: range))
            }
        }

        // Seed with the tiles under the grab point; a draggable boundary needs
        // a tile ending *and* a tile starting at the line right there.
        func containsAlong(_ range: ClosedRange<Double>) -> Bool {
            range.lowerBound - epsilon <= along && along <= range.upperBound + epsilon
        }
        var affected = Set(borderers.indices.filter { containsAlong(borderers[$0].range) })
        guard affected.contains(where: { borderers[$0].isLeading }),
              affected.contains(where: { !borderers[$0].isLeading }) else {
            return nil
        }

        // Closure over extent overlap (touching at a point doesn't chain).
        var changed = true
        while changed {
            changed = false
            for candidate in borderers.indices where !affected.contains(candidate) {
                if affected.contains(where: { overlaps(borderers[$0].range, borderers[candidate].range) }) {
                    affected.insert(candidate)
                    changed = true
                }
            }
        }

        let leading = affected.filter { borderers[$0].isLeading }.map { borderers[$0].tileIndex }.sorted()
        let trailing = affected.filter { !borderers[$0].isLeading }.map { borderers[$0].tileIndex }.sorted()
        return LayoutBoundary(orientation: orientation, position: position, leadingTiles: leading, trailingTiles: trailing)
    }

    /// Moves `boundary` to `newPosition`, clamped so no affected tile shrinks
    /// below `minTileSize` on the dragged axis.
    public static func movingBoundary(
        _ layout: Layout, boundary: LayoutBoundary, to newPosition: Double, minTileSize: Double
    ) -> Layout {
        var tiles = layout.tiles

        // Clamp: leading tiles must keep at least minTileSize of extent before
        // the line, trailing tiles at least minTileSize after it.
        var lowerLimit = 0.0
        var upperLimit = 1.0
        for index in boundary.leadingTiles where tiles.indices.contains(index) {
            let start = boundary.orientation == .vertical ? tiles[index].x : tiles[index].y
            lowerLimit = max(lowerLimit, start + minTileSize)
        }
        for index in boundary.trailingTiles where tiles.indices.contains(index) {
            let end = boundary.orientation == .vertical ? tiles[index].maxX : tiles[index].maxY
            upperLimit = min(upperLimit, end - minTileSize)
        }
        guard lowerLimit <= upperLimit else { return layout }
        let clamped = min(max(newPosition, lowerLimit), upperLimit)

        for index in boundary.leadingTiles where tiles.indices.contains(index) {
            var tile = tiles[index]
            switch boundary.orientation {
            case .vertical: tile.width = clamped - tile.x
            case .horizontal: tile.height = clamped - tile.y
            }
            tiles[index] = tile
        }
        for index in boundary.trailingTiles where tiles.indices.contains(index) {
            var tile = tiles[index]
            switch boundary.orientation {
            case .vertical:
                tile.width = tile.maxX - clamped
                tile.x = clamped
            case .horizontal:
                tile.height = tile.maxY - clamped
                tile.y = clamped
            }
            tiles[index] = tile
        }
        return Layout(id: layout.id, tiles: tiles)
    }

    // MARK: - Groups

    /// Recomputes Tiling Shell-compatible `groups`: each shared edge segment
    /// between an adjacent pair of tiles gets a unique id, and every tile
    /// carries the ids of the segments it borders. (This is the shape the
    /// Tiling Shell editor produces — e.g. its 2x2 grid is
    /// `[1,3] [1,4] [2,3] [2,4]`.) Call once when saving from the editor.
    public static func recomputingGroups(_ layout: Layout) -> Layout {
        var groupsPerTile = [[Int]](repeating: [], count: layout.tiles.count)
        var nextID = 1

        for i in layout.tiles.indices {
            for j in layout.tiles.indices where j > i {
                let a = layout.tiles[i]
                let b = layout.tiles[j]
                let sharesVertical =
                    (nearly(a.maxX, b.x) || nearly(b.maxX, a.x)) && overlaps(a.y...a.maxY, b.y...b.maxY)
                let sharesHorizontal =
                    (nearly(a.maxY, b.y) || nearly(b.maxY, a.y)) && overlaps(a.x...a.maxX, b.x...b.maxX)
                if sharesVertical || sharesHorizontal {
                    groupsPerTile[i].append(nextID)
                    groupsPerTile[j].append(nextID)
                    nextID += 1
                }
            }
        }

        let tiles = layout.tiles.enumerated().map { index, tile in
            Tile(x: tile.x, y: tile.y, width: tile.width, height: tile.height, groups: groupsPerTile[index])
        }
        return Layout(id: layout.id, tiles: tiles)
    }

    // MARK: - Helpers

    private static func nearly(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < epsilon
    }

    /// True when two ranges overlap by more than a point (touching corners
    /// don't count as a shared edge).
    private static func overlaps(_ a: ClosedRange<Double>, _ b: ClosedRange<Double>) -> Bool {
        min(a.upperBound, b.upperBound) - max(a.lowerBound, b.lowerBound) > epsilon
    }
}
